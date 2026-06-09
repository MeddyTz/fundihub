# FundiHub Phase 11.5 Selcom Test Backend

Use Selcom test/sandbox credentials first.

## Replace files
Copy the `functions` folder contents into your project `functions` folder.

## Install
```bash
cd functions
npm install
```

## Env
Create `functions/.env` from `.env.example` and fill your Selcom TEST credentials.

## Deploy
```bash
firebase deploy --only functions
```

## Flutter run
After deploy, run:
```bash
flutter run --debug --no-track-widget-creation --dart-define=FUNDIHUB_PAYMENTS_API_BASE_URL=https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/api
```

## Supported payments
- job_fee: Tsh 2,500
- premium_subscription: Tsh 35,000
- profile_boost/promotion: Tsh 10,000 placeholder

## Important
Confirm exact Selcom signature/header requirements with your Selcom credential package before going live.
