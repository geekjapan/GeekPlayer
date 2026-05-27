import 'package:flutter/foundation.dart';

/// Domain value object representing a local video Episode that the user
/// has chosen (or chosen previously) to open.
///
/// `uri` is the canonical key written to drift (`file://...`). `displayName`
/// is the file's basename — what we render in the recent-items list.
@immutable
class VideoFile {
  const VideoFile({required this.uri, required this.displayName});

  final Uri uri;
  final String displayName;

  /// URI as the string form persisted in drift (and used as the lookup
  /// key everywhere). Equivalent to `uri.toString()`.
  String get uriString => uri.toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoFile &&
        other.uri == uri &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(uri, displayName);

  @override
  String toString() => 'VideoFile($displayName, $uri)';
}
