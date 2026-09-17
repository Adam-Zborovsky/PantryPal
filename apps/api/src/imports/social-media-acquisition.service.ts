import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { isAbsolute, join, relative, resolve } from 'node:path';
import { ImportSourceError } from './source-adapter';
import type { SocialPlatform } from './social-source-classifier.service';

@Injectable()
export class SocialMediaAcquisitionService {
  constructor(private readonly config: ConfigService) {}

  async acquire(platform: SocialPlatform, canonicalUrl: string) {
    if (!this.isEnabled()) {
      throw new ImportSourceError(
        'MEDIA_DOWNLOAD_DISABLED',
        'Social-video processing is not enabled on this server yet. Paste the recipe caption or upload a screenshot instead.',
      );
    }
    const root = this.config.get<string>('MEDIA_TEMP_ROOT')?.trim() || tmpdir();
    await mkdir(root, { recursive: true });
    const directory = await mkdtemp(join(root, `pantrypal-${platform}-`));
    try {
      const outputPath = await this.download(canonicalUrl, directory);
      const output = await stat(outputPath);
      if (!output.isFile() || output.size <= 0) {
        throw new Error('Downloader produced no usable media file.');
      }
      if (output.size > this.maxBytes()) {
        throw new ImportSourceError(
          'MEDIA_TOO_LARGE_OR_LONG',
          'Downloaded social video exceeds the configured size limit.',
        );
      }
      return {
        path: outputPath,
        directory,
        cleanup: () => rm(directory, { recursive: true, force: true }),
      };
    } catch (error) {
      await rm(directory, { recursive: true, force: true });
      if (error instanceof ImportSourceError) throw error;
      throw new ImportSourceError(
        this.downloadErrorCode(error),
        error instanceof Error
          ? `Social-video download failed: ${error.message}`
          : 'Social-video download failed.',
      );
    }
  }

  private async download(canonicalUrl: string, directory: string) {
    const outputTemplate = join(directory, 'source.%(ext)s');
    const output = await this.run(this.ytDlpPath(), [
      '--no-playlist',
      '--no-progress',
      '--no-warnings',
      '--restrict-filenames',
      '--no-part',
      '--socket-timeout',
      '30',
      '--retries',
      '1',
      '--fragment-retries',
      '1',
      '--max-filesize',
      this.maxBytes().toString(),
      '--format',
      'bv*[height<=720]+ba/b[height<=720]/b',
      '--output',
      outputTemplate,
      '--print',
      'after_move:filepath',
      canonicalUrl,
    ]);
    const reportedPath = output
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
      .at(-1);
    if (!reportedPath)
      throw new Error('Downloader did not report an output path.');
    const resolvedDirectory = resolve(directory);
    const resolvedOutput = resolve(
      isAbsolute(reportedPath) ? reportedPath : join(directory, reportedPath),
    );
    if (
      relative(resolvedDirectory, resolvedOutput).startsWith('..') ||
      !resolvedOutput.startsWith(resolvedDirectory)
    ) {
      throw new Error(
        'Downloader returned a file outside its temporary directory.',
      );
    }
    return resolvedOutput;
  }

  private run(command: string, args: string[]) {
    return new Promise<string>((resolvePromise, reject) => {
      const child = spawn(command, args, {
        shell: false,
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      let stdout = '';
      let stderr = '';
      const timer = setTimeout(() => {
        child.kill();
        reject(new Error('Downloader timed out.'));
      }, 5 * 60_000);
      child.stdout.setEncoding('utf8');
      child.stderr.setEncoding('utf8');
      child.stdout.on('data', (chunk: string) => (stdout += chunk));
      child.stderr.on('data', (chunk: string) => (stderr += chunk));
      child.once('error', () => {
        clearTimeout(timer);
        reject(new Error('Downloader could not start.'));
      });
      child.once('close', (code) => {
        clearTimeout(timer);
        if (code === 0) resolvePromise(stdout);
        else
          reject(
            new Error(stderr.trim().slice(0, 400) || 'Downloader failed.'),
          );
      });
    });
  }

  private isEnabled() {
    return (
      this.config
        .get<string>('SOCIAL_MEDIA_DOWNLOAD_ENABLED')
        ?.trim()
        .toLowerCase() === 'true'
    );
  }

  private ytDlpPath() {
    return this.config.get<string>('YT_DLP_PATH')?.trim() || 'yt-dlp';
  }

  private maxBytes() {
    const configured = Number(this.config.get<string>('MEDIA_MAX_BYTES'));
    return Number.isSafeInteger(configured) && configured > 0
      ? configured
      : 500 * 1024 * 1024;
  }

  private downloadErrorCode(error: unknown) {
    const message = error instanceof Error ? error.message.toLowerCase() : '';
    return /private|login|required|not available/.test(message)
      ? 'SOURCE_PRIVATE_OR_LOGIN_REQUIRED'
      : 'MEDIA_PROCESSING_FAILED';
  }
}
