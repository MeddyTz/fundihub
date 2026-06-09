# FundiHub Selcom Payment Setup

This update makes all FundiHub payment entry points use Selcom checkout:

- `job_fee` = Tsh 2,500 job completion fee
- `subscription` = Tsh 35,000 premium subscription
- `promotion` = boost/profile promotion payments

## Important

Do **not** put Selcom API key/secret inside Flutter. The Flutter app calls your backend. The backend signs and calls Selcom.

## 1. Backend deployment

Copy `backend/functions` into a Firebase Functions project.

Install:

```bash
cd backend/functions
npm install
```

Set environment variables in your hosting/deployment environment:

```bash
SELCOM_BASE_URL=https://apigw.selcommobile.com
SELCOM_API_KEY=...
SELCOM_API_SECRET=...
SELCOM_VENDOR=...
FUNDIHUB_FUNCTIONS_BASE_URL=https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/api
FUNDIHUB_PAYMENT_REDIRECT_URL=https://fundihub.app/payment-result
FUNDIHUB_PAYMENT_CANCEL_URL=https://fundihub.app/payment-cancelled
SELCOM_WEBHOOK_TOKEN=long-random-secret
```

Deploy:

```bash
firebase deploy --only functions
```

## 2. Flutter run command

Run with your backend URL:

```bash
flutter run --dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/api
```

Build release with the same define:

```bash
flutter build apk --release --dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/api
```

## 3. Testing note

Public Selcom docs say the API currently has no general test mode. If Selcom gives you sandbox/test credentials, use those credentials in the backend environment first. Otherwise, test with a small real amount only after you are ready.

## 4. Flow

Flutter payment screen -> backend `/payments/selcom/checkout` -> Selcom checkout -> Selcom webhook -> Firestore update.

When webhook confirms payment:

- job fee: fundi wallet unlocks
- subscription: fundi becomes premium
- promotion: boost becomes active

## 5. Files changed

Flutter:

- `lib/core/config/selcom_config.dart`
- `lib/models/payment_model.dart`
- `lib/models/selcom_checkout_result.dart`
- `lib/providers/payment_provider.dart`
- `lib/services/payment_service.dart`
- `lib/screens/shared/payment_submit_screen.dart`
- `lib/screens/fundi/fundi_wallet_screen.dart`
- `lib/screens/fundi/fundi_promotion_screen.dart`
- `lib/widgets/cards/payment_card.dart`
- `pubspec.yaml`

Backend starter:

- `backend/functions/index.js`
- `backend/functions/package.json`
- `backend/functions/.env.example`
