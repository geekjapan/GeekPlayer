import 'package:flutter/foundation.dart';

import 'ml_backend.dart';
import 'ml_model_state.dart';

/// Describes the resolved ML upscaling capabilities (ADR-0007).
///
/// [preferred] is the platform's intended backend; [effective] is what will
/// actually run after probing execution-provider availability, model state,
/// and the experimental flag. [reason] explains why [effective] was chosen.
@immutable
class MlCapabilities {
  const MlCapabilities({
    required this.preferred,
    required this.effective,
    required this.modelState,
    required this.experimentalEnabled,
    required this.reason,
  });

  /// The platform-preferred backend (intent only).
  final MlBackend preferred;

  /// The backend that will actually be used.
  final MlBackend effective;

  /// Whether the upscaling model is present.
  final MlModelState modelState;

  /// Whether the experimental AI-upscaling feature is enabled.
  final bool experimentalEnabled;

  /// Human-readable explanation of the [effective] selection.
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MlCapabilities &&
          runtimeType == other.runtimeType &&
          preferred == other.preferred &&
          effective == other.effective &&
          modelState == other.modelState &&
          experimentalEnabled == other.experimentalEnabled &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(
    preferred,
    effective,
    modelState,
    experimentalEnabled,
    reason,
  );

  @override
  String toString() =>
      'MlCapabilities(preferred: $preferred, effective: $effective, '
      'modelState: $modelState, experimentalEnabled: $experimentalEnabled, '
      'reason: $reason)';
}
