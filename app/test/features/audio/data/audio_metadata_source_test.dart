import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/audio/data/audio_metadata_source.dart';
import 'package:geekplayer/features/audio/domain/audio_track.dart' as gp;
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  const AudioMetadataSource source = AudioMetadataSource();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_md_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('non-file URI returns empty metadata', () async {
    final gp.AudioMetadata md = await source.readMetadata(
      Uri.parse('https://example.com/x.mp3'),
    );
    expect(md.title, isNull);
    expect(md.artist, isNull);
    expect(md.album, isNull);
    expect(md.artworkBytes, isNull);
  });

  test('missing file returns empty metadata', () async {
    final gp.AudioMetadata md = await source.readMetadata(
      Uri.file(p.join(tempDir.path, 'missing.mp3')),
    );
    expect(md.title, isNull);
  });

  test('file with no parseable tags degrades to empty metadata', () async {
    // Random bytes — no valid container header. The parser should
    // throw internally and the source coerces that to empty fields.
    final File f = File(p.join(tempDir.path, 'garbage.mp3'));
    await f.writeAsBytes(List<int>.generate(64, (int i) => i & 0xff));
    final gp.AudioMetadata md = await source.readMetadata(Uri.file(f.path));
    expect(md.title, isNull);
    expect(md.artist, isNull);
    expect(md.album, isNull);
    expect(md.artworkBytes, isNull);
  });

  test('AudioTrack falls back to filename minus extension', () {
    final gp.AudioTrack t = gp.AudioTrack(
      uri: Uri.file('/music/sample.wav'),
      displayName: 'sample.wav',
    );
    expect(t.effectiveTitle, 'sample');
    expect(t.effectiveArtist, '不明なアーティスト');
    expect(t.effectiveAlbum, '');
  });
}
