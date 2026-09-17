import { parseMediaProbe } from './media-tool.service';

describe('parseMediaProbe', () => {
  it('accepts a valid audio stream and duration', () => {
    expect(
      parseMediaProbe(
        {
          format: { duration: '31.25', format_name: 'mov,mp4,m4a' },
          streams: [{ codec_type: 'audio', codec_name: 'aac' }],
        },
        'AUDIO',
      ),
    ).toEqual({
      durationSeconds: 31.25,
      formatNames: ['mov', 'mp4', 'm4a'],
      codecs: ['aac'],
      hasAudio: true,
    });
  });

  it('rejects a file without the expected stream', () => {
    expect(() =>
      parseMediaProbe(
        {
          format: { duration: '10' },
          streams: [{ codec_type: 'video', codec_name: 'h264' }],
        },
        'AUDIO',
      ),
    ).toThrow('no audio stream');
  });

  it('keeps a silent video eligible for visual analysis', () => {
    expect(
      parseMediaProbe(
        {
          format: { duration: '12', format_name: 'mov,mp4' },
          streams: [{ codec_type: 'video', codec_name: 'h264' }],
        },
        'VIDEO',
      ),
    ).toMatchObject({ durationSeconds: 12, hasAudio: false });
  });
});
