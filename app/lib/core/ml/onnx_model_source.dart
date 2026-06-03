import 'dart:io';

import 'package:flutter/foundation.dart';

/// An injected source for an ONNX model.
///
/// [OnnxImageUpscaler] is *given* a model; it never downloads, caches, or
/// otherwise sources one itself (that is the model-distribution capability).
/// Two forms are supported, mapping to the ONNX Runtime session constructors:
///
/// - [OnnxModelSource.file] → `OrtSession.fromFile`
/// - [OnnxModelSource.bytes] → `OrtSession.fromBuffer`
@immutable
sealed class OnnxModelSource {
  const OnnxModelSource();

  /// A model read from a file on disk.
  const factory OnnxModelSource.file(String path) = OnnxModelFileSource;

  /// A model already held in memory.
  const factory OnnxModelSource.bytes(Uint8List bytes) = OnnxModelBytesSource;
}

/// A model sourced from a file path.
class OnnxModelFileSource extends OnnxModelSource {
  const OnnxModelFileSource(this.path);

  final String path;

  File get file => File(path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnnxModelFileSource &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// A model sourced from in-memory bytes.
class OnnxModelBytesSource extends OnnxModelSource {
  const OnnxModelBytesSource(this.bytes);

  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnnxModelBytesSource &&
          runtimeType == other.runtimeType &&
          bytes == other.bytes;

  @override
  int get hashCode => bytes.hashCode;
}
