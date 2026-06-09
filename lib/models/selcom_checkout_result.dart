class SelcomCheckoutResult {
  final String paymentId;
  final String orderId;
  final String checkoutUrl;
  final String status;
  final String message;
  final Map<String, dynamic> raw;

  const SelcomCheckoutResult({
    required this.paymentId,
    required this.orderId,
    required this.checkoutUrl,
    required this.status,
    required this.message,
    required this.raw,
  });

  bool get hasCheckoutUrl => checkoutUrl.trim().isNotEmpty;

  factory SelcomCheckoutResult.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    final nested = json['data'];
    final data = nested is Map<String, dynamic> ? nested : <String, dynamic>{};
    final merged = <String, dynamic>{...json, ...data};

    String pickMerged(List<String> keys) {
      for (final key in keys) {
        final value = merged[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    return SelcomCheckoutResult(
      paymentId: pickMerged(['paymentId', 'payment_id', 'id', 'localPaymentId']),
      orderId: pickMerged(['orderId', 'order_id', 'orderReference', 'reference']),
      checkoutUrl: pickMerged(['checkoutUrl', 'checkout_url', 'paymentUrl', 'payment_url', 'redirectUrl', 'redirect_url']),
      status: pickMerged(['status', 'paymentStatus', 'result']).isEmpty
          ? 'pending'
          : pickMerged(['status', 'paymentStatus', 'result']),
      message: pick(['message', 'description', 'statusMessage']).isEmpty
          ? 'Selcom checkout created.'
          : pick(['message', 'description', 'statusMessage']),
      raw: json,
    );
  }
}
