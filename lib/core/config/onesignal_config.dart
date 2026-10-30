class OneSignalConfig {
  // Compile-time environment definitions loaded via --dart-define-from-file=.env
  static const String appId = String.fromEnvironment('ONESIGNAL_APP_ID');

  static const String restApiKey =
      String.fromEnvironment('ONESIGNAL_REST_API_KEY');

  static bool get isConfigured => appId.isNotEmpty;
}
