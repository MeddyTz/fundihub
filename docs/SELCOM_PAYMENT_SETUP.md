# FundiHub Selcom Payment Setup

## Important
Do NOT put Selcom vendor/API secrets in Flutter. The app now calls your secure backend using:

```bash
--dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://your-backend-url
--dart-define=FUNDIHUB_SELCOM_SANDBOX=true
```

Your backend must expose:

```http
POST /payments/selcom/checkout
```

Expected request from Flutter:

```json
{
  "paymentId": "local Firestore payment id",
  "orderId": "FH-...",
  "amount": 2500,
  "currency": "TZS",
  "paymentType": "job_fee",
  "relatedBookingId": "optional booking id",
  "durationDays": 7,
  "customer": {
    "id": "firebase uid",
    "name": "Fundi Name",
    "email": "email@example.com",
    "phone": "07XXXXXXXX"
  },
  "sandbox": true,
  "source": "fundihub_flutter"
}
```

Expected backend response:

```json
{
  "paymentId": "same payment id",
  "orderId": "Selcom/order reference",
  "checkoutUrl": "https://...",
  "status": "pending",
  "message": "Checkout created"
}
```

Your backend webhook/callback must update Firestore:

```js
payments/{paymentId}.status = "confirmed" | "rejected"
payments/{paymentId}.providerStatus = "paid" | "failed"
payments/{paymentId}.providerTransactionId = "..."
payments/{paymentId}.confirmedAt = serverTimestamp()
```

When confirming job fee payments, also unlock the fundi wallet:

```js
wallets/{fundiId}.lockedReason = "none"
wallets/{fundiId}.feeStatus = "paid"
wallets/{fundiId}.pendingJobFee = 0
```

For subscriptions, set:

```js
users/{fundiId}.plan = "premium"
wallets/{fundiId}.subscriptionStatus = "premium"
```

## Flutter run example

```bash
flutter run --dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://api.yourdomain.com --dart-define=FUNDIHUB_SELCOM_SANDBOX=true
```

## Production build example

```bash
flutter build apk --release --dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://api.yourdomain.com --dart-define=FUNDIHUB_SELCOM_SANDBOX=false
```
