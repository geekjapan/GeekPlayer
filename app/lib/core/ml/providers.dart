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
/// Ships [CpuImageUpscaler] by default. Concrete backend
/// implementations (CoreML, NNAPI, etc.) override this provider once
/// available.
@Riverpod(keepAlive: true)
ImageUpscaler imageUpscaler(Ref ref) => const CpuImageUpscaler();
