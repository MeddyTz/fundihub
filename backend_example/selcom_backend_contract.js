/**
 * This is NOT a ready-to-deploy Selcom backend.
 * It is the contract your backend/Cloud Function should implement.
 * Keep Selcom vendor/API secrets only on the server.
 */

// POST /payments/selcom/checkout
async function createSelcomCheckout(req, res) {
  const {
    paymentId,
    orderId,
    amount,
    currency,
    paymentType,
    relatedBookingId,
    customer,
    sandbox,
  } = req.body;

  // 1. Validate Firebase auth token from req.headers.authorization.
  // 2. Validate the user can create this payment.
  // 3. Sign Selcom request using vendor/API secrets on server.
  // 4. Call Selcom Checkout API.
  // 5. Save/merge provider fields into Firestore payments/{paymentId}.
  // 6. Return checkout URL to Flutter.

  return res.json({
    paymentId,
    orderId,
    checkoutUrl: 'https://selcom-checkout-url-from-api',
    status: 'pending',
    message: 'Checkout created',
  });
}

// POST /payments/selcom/webhook
async function selcomWebhook(req, res) {
  // 1. Verify Selcom signature.
  // 2. Find payments/{paymentId} by order/reference.
  // 3. If paid, set status confirmed and unlock wallet/subscription/promotion.
  // 4. If failed, set rejected.
  return res.json({ ok: true });
}
