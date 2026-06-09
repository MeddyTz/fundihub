class SelcomConfig {
  SelcomConfig._();

  /// IMPORTANT:
  /// Never put Selcom vendor/API secrets inside Flutter.
  /// This URL must point to your secure backend / Cloud Function that signs Selcom requests.
  /// Run example:
  /// flutter run --dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://your-domain.com
  static const String backendBaseUrl = String.fromEnvironment(
    'FUNDIHUB_PAYMENTS_API_BASE_URL',
    defaultValue: '',
  );

  static const bool sandboxMode = bool.fromEnvironment(
    'FUNDIHUB_SELCOM_SANDBOX',
    defaultValue: true,
  );

  static bool get isConfigured => backendBaseUrl.trim().isNotEmpty;

  static String get _base => backendBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  static String get checkoutEndpoint => '$_base/payments/selcom/checkout';
  static String get statusEndpoint => '$_base/payments/selcom/status';
}
