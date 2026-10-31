import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../subscription/services/revenuecat_service.dart';
import '../models/auth_state.dart';

final authStorageProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final authState = ref.watch(authProvider);
  final lang = ref.watch(appLanguageProvider);

  return ApiClient(
    getBaseUrl: () => baseUrl,
    getAccessToken: () => authState.accessToken,
    getLocale: () => lang.code,
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(authStorageProvider);
  return AuthNotifier(
    storage,
    () => ref.read(apiBaseUrlProvider),
    () => ref.read(appLanguageProvider).code,
    (backendLocale) {
      ref.read(appLanguageProvider.notifier).setLanguageFromBackend(backendLocale);
    },
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final StorageService _storage;
  final String Function() _getBaseUrl;
  final String Function() _getCurrentLocale;
  final void Function(String) _onLocaleSynced;

  static const _keyAccess = 'jwt_access_token';
  static const _keyRefresh = 'jwt_refresh_token';
  static const _keyUser = 'user_profile_json';

  AuthNotifier(
    this._storage,
    this._getBaseUrl,
    this._getCurrentLocale,
    this._onLocaleSynced,
  ) : super(const AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final access = await _storage.read(_keyAccess);
      final refresh = await _storage.read(_keyRefresh);
      final userStr = await _storage.read(_keyUser);

      if (access != null && access.isNotEmpty && userStr != null) {
        final user = UserProfile.fromJson(jsonDecode(userStr));
        // Link identity with RevenueCat
        RevenueCatService.instance.logIn(user.id);
        if (user.locale.isNotEmpty) {
          _onLocaleSynced(user.locale);
        }
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          accessToken: access,
          refreshToken: refresh,
          user: user,
        );
        return;
      }
    } catch (_) {}

    state = state.copyWith(
      isAuthenticated: false,
      isLoading: false,
      accessToken: null,
      refreshToken: null,
      user: null,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final client = ApiClient(
      getBaseUrl: _getBaseUrl,
      getAccessToken: () => null,
      getLocale: _getCurrentLocale,
    );

    try {
      final resp = await client.post(
        '/api/v1/auth/login',
        body: {'email': email.trim(), 'password': password},
      );

      final accessToken = resp['access_token'] as String;
      final refreshToken = resp['refresh_token'] as String;
      final user = UserProfile.fromJson(resp['user']);

      await _storage.write(_keyAccess, accessToken);
      await _storage.write(_keyRefresh, refreshToken);
      await _storage.write(_keyUser, jsonEncode(user.toJson()));

      // Link user ID to RevenueCat
      RevenueCatService.instance.logIn(user.id);

      // Sync user language preference across devices
      if (user.locale.isNotEmpty) {
        _onLocaleSynced(user.locale);
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final client = ApiClient(
      getBaseUrl: _getBaseUrl,
      getAccessToken: () => null,
      getLocale: _getCurrentLocale,
    );

    try {
      final currentLocale = _getCurrentLocale();
      final resp = await client.post(
        '/api/v1/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'locale': currentLocale,
        },
      );

      final accessToken = resp['access_token'] as String;
      final refreshToken = resp['refresh_token'] as String;
      final user = UserProfile.fromJson(resp['user']);

      await _storage.write(_keyAccess, accessToken);
      await _storage.write(_keyRefresh, refreshToken);
      await _storage.write(_keyUser, jsonEncode(user.toJson()));

      // Link user ID to RevenueCat
      RevenueCatService.instance.logIn(user.id);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    final refresh = state.refreshToken;
    final token = state.accessToken;

    if (refresh != null) {
      final client = ApiClient(
        getBaseUrl: _getBaseUrl,
        getAccessToken: () => token,
        getLocale: _getCurrentLocale,
      );
      try {
        await client.post(
          '/api/v1/auth/logout',
          body: {'refresh_token': refresh},
        );
      } catch (_) {}
    }

    // Reset RevenueCat identity on logout
    RevenueCatService.instance.logOut();

    await _storage.deleteAll();
    state = const AuthState(isLoading: false);
  }

  /// Permanently deletes the user account and purges local credentials (Google Play requirement)
  Future<bool> deleteAccount() async {
    final token = state.accessToken;
    if (token == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    final client = ApiClient(
      getBaseUrl: _getBaseUrl,
      getAccessToken: () => token,
      getLocale: _getCurrentLocale,
    );

    try {
      await client.delete('/api/v1/me');
      // Reset RevenueCat identity
      RevenueCatService.instance.logOut();
      await _storage.deleteAll();
      state = const AuthState(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Hisobni o\'chirishda xatolik: $e',
      );
      return false;
    }
  }
}
