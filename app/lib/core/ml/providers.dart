import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'cpu_image_upscaler.dart';
import 'image_upscaler.dart';
import 'ml_runtime.dart';

part 'providers.g.dart';

/// Provides the [MlRuntime] singleton used across the app.
///
/// Tests can override this with a custom [MlRuntime] constructed with
/// a fake [TargetPlatformResolver] to exercise any platform branch.
@Riverpod(keepAlive: true)
MlRuntime mlRuntime(Ref ref) => const MlRuntime();

/// Provides the active [ImageUpscaler] implementation.
///
/// Ships [CpuImageUpscaler] (the bicubic floor) by default. ADR-0007 step 2
/// adds an `OnnxImageUpscaler` and a pure `resolveImageUpscaler` seam, but this
/// provider stays the synchronous floor here: AI upscaling is experimental and
/// default-OFF and no model is sourced yet, so the effective backend is always
/// `bicubicCpu`. Making this provider async (probe + model presence) and
/// migrating the manga viewer is deferred to the model-distribution change.
@Riverpod(keepAlive: true)
ImageUpscaler imageUpscaler(Ref ref) => const CpuImageUpscaler();
