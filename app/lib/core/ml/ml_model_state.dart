/// Availability of the on-device upscaling model (ADR-0007).
///
/// Models are opt-in and downloaded on first use, so until a model is present
/// the effective backend stays on the `bicubicCpu` floor.
enum MlModelState {
  /// No model has been downloaded yet.
  absent,

  /// A usable model is present on disk.
  present,
}
