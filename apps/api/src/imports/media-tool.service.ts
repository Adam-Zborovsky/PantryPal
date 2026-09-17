import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaKind } from '@prisma/client';
import { spawn } from 'node:child_process';
import { mkdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import type { ImportErrorCode } from './import-errors';

export class MediaToolError extends Error {
  constructor(
    readonly code: Extract<
      ImportErrorCode,
      'MEDIA_TOO_LARGE_OR_LONG' | 'MEDIA_PROCESSING_FAILED'
    >,
    message: string,
  ) {
    super(message);
  }
}

export type MediaProbe = {
  durationSeconds: number;
  formatNames: string[];
  codecs: string[];
  hasAudio: boolean;
};

export type VideoFrame = {
  path: string;
  byteSize: number;
  mimeType: 'image/jpeg';
  timestampMs: number;
  frameIndex: number;
};

export function parseMediaProbe(value: unknown, kind: MediaKind): MediaProbe {
  if (!value || typeof value !== 'object')
    throw new Error('FFprobe returned no JSON object.');
  const record = value as Record<string, unknown>;
  const format = record.format as Record<string, unknown> | undefined;
  const durationSeconds = Number(format?.duration);
  const streams = Array.isArray(record.streams) ? record.streams : [];
  const usableStreams = streams.filter(
    (stream): stream is Record<string, unknown> =>
      !!stream && typeof stream === 'object',
  );
  const expectedType = kind === 'VIDEO' ? 'video' : 'audio';
  if (!usableStreams.some((stream) => stream.codec_type === expectedType)) {
    throw new Error(`The file has no ${expectedType} stream.`);
  }
  if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) {
    throw new Error('The file has no usable duration.');
  }
  return {
    durationSeconds,
    formatNames: String(format?.format_name ?? '')
      .split(',')
      .filter(Boolean),
    codecs: usableStreams
      .map((stream) => stream.codec_name)
      .filter((codec): codec is string => typeof codec === 'string'),
    hasAudio: usableStreams.some((stream) => stream.codec_type === 'audio'),
  };
}

@Injectable()
export class MediaToolService {
  constructor(private readonly config: ConfigService) {}

  async probe(path: string, kind: MediaKind) {
    const output = await this.run(this.ffprobePath(), [
      '-v',
      'error',
      '-show_entries',
      'format=duration,format_name:stream=codec_type,codec_name',
      '-of',
      'json',
      path,
    ]);
    let probe: MediaProbe;
    try {
      probe = parseMediaProbe(JSON.parse(output), kind);
    } catch (error) {
      throw new MediaToolError(
        'MEDIA_PROCESSING_FAILED',
        error instanceof Error
          ? `Media probe failed: ${error.message}`
          : 'Media probe failed.',
      );
    }
    if (probe.durationSeconds > this.maxDurationSeconds()) {
      throw new MediaToolError(
        'MEDIA_TOO_LARGE_OR_LONG',
        'Media exceeds the configured 30-minute duration limit.',
      );
    }
    return probe;
  }

  async extractMonoFlac(inputPath: string, directory: string) {
    const outputPath = join(directory, 'analysis-audio.flac');
    await this.run(this.ffmpegPath(), [
      '-nostdin',
      '-y',
      '-i',
      inputPath,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'flac',
      outputPath,
    ]);
    const output = await stat(outputPath);
    if (output.size <= 0 || output.size > this.maxBytes()) {
      throw new MediaToolError(
        'MEDIA_TOO_LARGE_OR_LONG',
        'Extracted audio exceeds the configured size limit.',
      );
    }
    return { path: outputPath, byteSize: output.size, mimeType: 'audio/flac' };
  }

  async extractVideoFrames(
    inputPath: string,
    directory: string,
    durationSeconds: number,
  ): Promise<VideoFrame[]> {
    const timestamps = this.videoFrameTimestamps(durationSeconds);
    const framesDirectory = join(directory, 'analysis-frames');
    await mkdir(framesDirectory, { recursive: true });
    const frames: VideoFrame[] = [];
    let totalBytes = 0;
    try {
      for (const [frameIndex, timestampSeconds] of timestamps.entries()) {
        const outputPath = join(
          framesDirectory,
          `frame-${String(frameIndex + 1).padStart(2, '0')}.jpg`,
        );
        await this.run(this.ffmpegPath(), [
          '-nostdin',
          '-y',
          '-ss',
          timestampSeconds.toFixed(3),
          '-i',
          inputPath,
          '-map',
          '0:v:0',
          '-frames:v',
          '1',
          '-vf',
          'scale=1280:-2:force_original_aspect_ratio=decrease',
          '-q:v',
          '5',
          outputPath,
        ]);
        const output = await stat(outputPath);
        totalBytes += output.size;
        if (output.size <= 0 || output.size > 2 * 1024 * 1024) {
          throw new Error('A sampled video frame exceeds the 2 MB limit.');
        }
        if (totalBytes > 8 * 1024 * 1024) {
          throw new Error('Sampled video frames exceed the 8 MB total limit.');
        }
        frames.push({
          path: outputPath,
          byteSize: output.size,
          mimeType: 'image/jpeg',
          timestampMs: Math.round(timestampSeconds * 1000),
          frameIndex,
        });
      }
      return frames;
    } catch (error) {
      if (error instanceof MediaToolError) throw error;
      throw new MediaToolError(
        'MEDIA_PROCESSING_FAILED',
        error instanceof Error
          ? `Video frame extraction failed: ${error.message}`
          : 'Video frame extraction failed.',
      );
    }
  }

  private async run(command: string, args: string[]) {
    return new Promise<string>((resolve, reject) => {
      const child = spawn(command, args, {
        shell: false,
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      let stdout = '';
      let stderr = '';
      const timer = setTimeout(() => {
        child.kill();
        reject(
          new MediaToolError(
            'MEDIA_PROCESSING_FAILED',
            'Media tool timed out.',
          ),
        );
      }, 60_000);
      child.stdout.setEncoding('utf8');
      child.stderr.setEncoding('utf8');
      child.stdout.on('data', (chunk: string) => (stdout += chunk));
      child.stderr.on('data', (chunk: string) => (stderr += chunk));
      child.once('error', () => {
        clearTimeout(timer);
        reject(
          new MediaToolError(
            'MEDIA_PROCESSING_FAILED',
            'Media tool could not start.',
          ),
        );
      });
      child.once('close', (code) => {
        clearTimeout(timer);
        if (code === 0) resolve(stdout);
        else {
          reject(
            new MediaToolError(
              'MEDIA_PROCESSING_FAILED',
              `Media tool failed${stderr.trim() ? `: ${stderr.trim().slice(0, 400)}` : '.'}`,
            ),
          );
        }
      });
    });
  }

  private ffprobePath() {
    return this.config.get<string>('FFPROBE_PATH')?.trim() || 'ffprobe';
  }

  private ffmpegPath() {
    return this.config.get<string>('FFMPEG_PATH')?.trim() || 'ffmpeg';
  }

  private maxDurationSeconds() {
    const configured = Number(
      this.config.get<string>('MEDIA_MAX_DURATION_SECONDS'),
    );
    return Number.isSafeInteger(configured) && configured > 0
      ? configured
      : 1800;
  }

  private maxBytes() {
    const configured = Number(this.config.get<string>('MEDIA_MAX_BYTES'));
    return Number.isSafeInteger(configured) && configured > 0
      ? configured
      : 500 * 1024 * 1024;
  }

  private videoFrameTimestamps(durationSeconds: number) {
    return [0.125, 0.375, 0.625, 0.875].map(
      (position) => durationSeconds * position,
    );
  }
}
