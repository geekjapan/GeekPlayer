import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'github_update_checker.dart';
import 'update_checker.dart';

part 'update_checker_provider.g.dart';

/// Provides the live [UpdateChecker] implementation.
///
/// Tests override this with a [FakeUpdateChecker] via
/// `ProviderScope(overrides: [updateCheckerProvider.overrideWithValue(...)])`.
@Riverpod(keepAlive: true)
UpdateChecker updateChecker(Ref ref) => GithubUpdateChecker();
