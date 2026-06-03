// Helper script to create test fixture archives.
// Run once: dart test/fixtures/manga/create_fixtures.dart
// The generated .cbz / .zip files are committed to the repository and used by
// archive_inspector_test.dart and migration_v4_to_v5_test.dart.
//
// This file is NOT a test itself — it is a standalone generator.

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const String _dir = 'test/fixtures/manga';

/// Minimal 1×1 pixel PNG (white, no alpha).
final Uint8List _minimalPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk length+type
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // bit depth, colour type, crc
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT header
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, // deflate
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, // crc
  0xE7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Archive _buildNormalArchive() {
  final Archive archive = Archive();
  // Use numeric names to verify natural ordering.
  for (final String name in <String>['1.jpg', '10.jpg', '2.jpg']) {
    archive.addFile(ArchiveFile(name, _minimalPng.length, _minimalPng));
  }
  return archive;
}

Archive _buildMixedArchive() {
  final Archive archive = Archive();
  archive.addFile(ArchiveFile('001.jpg', _minimalPng.length, _minimalPng));
  archive.addFile(
    ArchiveFile(
      'notes.txt',
      5,
      Uint8List.fromList(<int>[104, 101, 108, 108, 111]),
    ),
  );
  archive.addFile(ArchiveFile('002.png', _minimalPng.length, _minimalPng));
  return archive;
}

Archive _buildTraversalArchive() {
  final Archive archive = Archive();
  archive.addFile(ArchiveFile('001.jpg', _minimalPng.length, _minimalPng));
  // Traversal entry — must be ignored.
  archive.addFile(ArchiveFile('../evil.jpg', _minimalPng.length, _minimalPng));
  return archive;
}

Archive _buildEmptyArchive() {
  // Archive with only a text file — no images.
  final Archive archive = Archive();
  archive.addFile(
    ArchiveFile(
      'readme.txt',
      5,
      Uint8List.fromList(<int>[104, 101, 108, 108, 111]),
    ),
  );
  return archive;
}

void _write(String name, Archive archive) {
  final List<int> bytes = ZipEncoder().encode(archive);
  File('$_dir/$name').writeAsBytesSync(bytes);
  stderr.writeln('Wrote $_dir/$name (${bytes.length} bytes)');
}

void _writeCorrupt(String name) {
  // Not a valid ZIP — just random bytes.
  File(
    '$_dir/$name',
  ).writeAsBytesSync(Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF, 0x00]));
  stderr.writeln('Wrote $_dir/$name (corrupt)');
}

void main() {
  Directory(_dir).createSync(recursive: true);

  _write('normal.cbz', _buildNormalArchive());
  _write('mixed_entries.cbz', _buildMixedArchive());
  _write('traversal.cbz', _buildTraversalArchive());
  _write('empty_pages.cbz', _buildEmptyArchive());
  _writeCorrupt('corrupt.cbz');

  stderr.writeln('Done.');
}
