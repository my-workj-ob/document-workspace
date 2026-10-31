import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_service.dart';

class OnboardingState {
  final bool isLoaded;
  final bool hasCompleted;

  const OnboardingState({
    this.isLoaded = false,
    this.hasCompleted = false,
  });

  OnboardingState copyWith({
    bool? isLoaded,
    bool? hasCompleted,
  }) {
    return OnboardingState(
      isLoaded: isLoaded ?? this.isLoaded,
      hasCompleted: hasCompleted ?? this.hasCompleted,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final StorageService _storage;
  static const _key = 'has_completed_onboarding_v1';

  OnboardingNotifier(this._storage) : super(const OnboardingState()) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final val = await _storage.read(_key);
      state = OnboardingState(
        isLoaded: true,
        hasCompleted: val == 'true',
      );
    } catch (_) {
      state = const OnboardingState(isLoaded: true, hasCompleted: false);
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(hasCompleted: true);
    await _storage.write(_key, 'true');
  }

  Future<void> resetOnboarding() async {
    state = state.copyWith(hasCompleted: false);
    await _storage.write(_key, 'false');
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(StorageService());
});
