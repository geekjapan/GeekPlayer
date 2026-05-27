import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_info_provider.g.dart';

/// Live application metadata (name, version, buildNumber) sourced from
/// `package_info_plus`.
///
/// Spec `about-screen` Requirement "About screen displays application
/// identity" — `package_info_plus` is the runtime source of these fields.
@Riverpod(keepAlive: true)
Future<PackageInfo> packageInfo(Ref ref) => PackageInfo.fromPlatform();
