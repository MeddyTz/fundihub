# FundiHub Phase 1 — Testing Checklist & Migration Notes

## DEPLOY COMMANDS (run in order)

```bash
# 1. Install new Cloud Functions dependencies
cd functions && npm install && cd ..

# 2. Deploy Firestore rules
firebase deploy --only firestore:rules

# 3. Deploy Firestore indexes
firebase deploy --only firestore:indexes

# 4. Deploy Storage rules
firebase deploy --only storage

# 5. Deploy Cloud Functions
firebase deploy --only functions

# 6. Flutter: add cloud_functions package
flutter pub get
```

---

## REQUIRED ENVIRONMENT VARIABLES (functions/.env)

```
BOOKING_EXPIRY_HOURS=48
SELCOM_VENDOR=           # leave blank until Selcom is integrated
SELCOM_API_KEY=          # leave blank until Selcom is integrated
SELCOM_API_SECRET=       # leave blank until Selcom is integrated
APP_RETURN_URL=fundihub://payment-result
SELCOM_CALLBACK_URL=     # leave blank until Selcom is integrated
```

---

## ONE-TIME ADMIN SETUP: Set admin custom claim

After deploying functions, run this once to grant admin role to your admin user:

```javascript
// From Firebase console > Functions > Shell, or a temporary admin script:
const admin = require('firebase-admin');
await admin.auth().setCustomUserClaims('ADMIN_USER_UID_HERE', { role: 'admin' });
// Then also update the Firestore users doc:
await admin.firestore().doc('users/ADMIN_USER_UID_HERE').update({ role: 'admin' });
```

Or call `setAdminRoleClaim` from another admin account once you have one.

---

## TESTING CHECKLIST

### TEST 1 — Role Escalation Prevention 🔴 CRITICAL
1. Log in as a regular client or fundi.
2. Open any Firestore REST client (e.g. Postman or Firestore emulator).
3. Attempt to PATCH `users/{yourUid}` with `{ "role": "admin" }`.
4. **Expected:** HTTP 403 PERMISSION_DENIED. The write is blocked.
5. Attempt to PATCH with `{ "plan": "premium" }` — also must be blocked.
6. Verify safe fields (fullName, bio, phone) CAN be updated by the owner.

### TEST 2 — Wallet Self-Write Prevention 🔴 CRITICAL
1. Log in as a free fundi with a locked wallet.
2. Attempt to PATCH `wallets/{fundiId}` with `{ "lockedReason": "none" }`.
3. **Expected:** HTTP 403 PERMISSION_DENIED. Wallet is read-only for fundis.
4. Attempt to write `{ "subscriptionStatus": "premium" }` — also blocked.
5. Verify the fundi CAN read their own wallet (GET succeeds).

### TEST 3 — Booking Field Restriction 🔴 CRITICAL
3a. As CLIENT:
    - Attempt to PATCH a booking with `{ "status": "completed" }` — BLOCKED.
    - Attempt to set `{ "contactUnlocked": true }` directly — BLOCKED.
    - CAN set `{ "clientAgreed": true }` when status = "accepted" — ALLOWED.
3b. As FUNDI:
    - Attempt to set `{ "fundiAgreed": true, "contactUnlocked": true }` — fundiAgreed ALLOWED, contactUnlocked BLOCKED.
    - Attempt to set `{ "status": "completed" }` when status = "accepted" (not in_progress) — BLOCKED.
    - CAN set `{ "status": "completed" }` when status = "in_progress" — ALLOWED.

### TEST 4 — Free Fundi Active-Job Lock (Server-Side) 🔴 CRITICAL
1. Register two fundis (both free plan).
2. Create two bookings for Fundi A.
3. Fundi A accepts Booking 1 — succeeds.
4. Fundi A tries to accept Booking 2:
   - **Expected:** Exception "Free plan allows only one active job at a time."
   - Verify the check fires from `booking_service.dart runTransaction`, not just UI.
5. Test with a Firestore REST call to update booking 2 status to "accepted" directly:
   - **Expected:** 403 (Firestore rule blocks fundi updating status to accepted from pending without the transaction check — but this is partial; main server protection is the transaction).

### TEST 5 — Promotion Does NOT Auto-Activate 🔴 CRITICAL
1. Log in as a fundi.
2. Go to Boost Profile → select Weekly Boost → Submit Payment Reference.
3. Enter a reference number → Submit.
4. Check Firestore `payments` collection:
   - **Expected:** `status = "submitted"` — NOT "confirmed".
5. Check `promotions` collection — NO new document should exist yet.
6. Check `users/{fundiId}.boostActive` — still `false`.
7. Check `wallets/{fundiId}.promotionStatus` — still `"inactive"`.
8. Go to admin panel → Payments → find the payment → click Confirm.
9. Wait ~5 seconds for `onPaymentWrite` CF to fire.
10. Re-check `promotions`, `users`, `wallets` — promotion now active.

### TEST 6 — Job Fee Does NOT Auto-Unlock 🔴 CRITICAL
1. Complete a job as a free fundi.
2. Check wallet is locked (`lockedReason = "job_fee_unpaid"`).
3. Go to Wallet screen → Pay Fee → Submit reference.
4. Check `payments` collection: `status = "submitted"`.
5. Fundi dashboard still shows "locked" — account NOT yet unlocked.
6. Admin confirms the payment.
7. `onPaymentWrite` CF fires → wallet unlocked.
8. Fundi can now accept new jobs.

### TEST 7 — Cross-User Notifications Arrive 🔴 CRITICAL
7a. Client creates a booking.
   - Fundi device: should receive a notification (bell badge +1, type = "booking_request").
   - This is now sent by `onBookingWrite` CF with Admin SDK.
7b. Fundi accepts the booking.
   - Client device: should receive "Booking Accepted" notification.
7c. Both confirm agreement.
   - Both devices: "Agreement Confirmed" notification.
7d. Fundi marks job started.
   - Client: "Job Started" notification.
7e. Fundi marks job completed.
   - Client: "Job Completed" notification.

**Note:** If notifications appear with a delay (~2-10s), that is expected (CF cold start).

### TEST 8 — Subscription Activates Only After Admin Approval
1. Fundi submits subscription payment (Tsh 35,000 reference).
2. Check `users/{fundiId}.plan` — still `"free"`.
3. Admin confirms payment.
4. `onPaymentWrite` CF fires.
5. Check `users/{fundiId}.plan` = `"premium"`, `wallets.subscriptionStatus` = `"premium"`.
6. Check `subscriptions` collection — new doc with `isActive: true`.

### TEST 9 — Storage: Non-Participant Cannot Upload to Chat
1. Get a valid chatId for a booking between User A and User B.
2. Log in as User C (not a participant).
3. Attempt to upload a file to `chats/{thatChatId}/test.jpg`.
4. **Expected:** Firebase Storage error (permission denied).
5. Log in as User A (participant) — upload succeeds.

### TEST 10 — Phone Number Blocking
10a. Before agreement: try sending "07 123 45678" — BLOCKED.
10b. Try "07.123.45678" (dots) — BLOCKED (new regex handles dots).
10c. Try "+255 712 345 678" — BLOCKED.
10d. After both agree: same numbers — ALLOWED (contactUnlocked = true).

### TEST 11 — Booking Expiry (Scheduled Function)
1. Manually create a booking in Firestore with:
   - `status: "pending"`
   - `createdAt: [timestamp 49+ hours ago]`
2. Wait for `scheduledBookingExpiry` to run (every 1 hour), OR trigger manually via Firebase Console > Functions > Run.
3. **Expected:** Booking `status` changes to `"expired"`.
4. Both parties receive "Booking Expired" notification.

### TEST 12 — Subscription Expiry
1. Create a subscription doc with:
   - `isActive: true`
   - `endDate: [timestamp in the past]`
2. Trigger `scheduledSubscriptionExpiry` manually.
3. **Expected:**
   - Subscription `isActive` → `false`.
   - `users/{fundiId}.plan` → `"free"`.
   - `wallets/{fundiId}.subscriptionStatus` → `"free"`.
   - Fundi receives "Premium Subscription Expired" notification.

### TEST 13 — Promotion Expiry
1. Create a promotion doc with `isActive: true`, `endDate: [past]`.
2. Trigger `scheduledPromotionExpiry`.
3. **Expected:**
   - Promotion `isActive` → `false`, `status` → `"expired"`.
   - `users/{fundiId}.boostActive` → `false`.
   - Fundi receives "Profile Boost Expired" notification.

### TEST 14 — Play Store Manifest Checks
1. Open Android Studio → check AndroidManifest.xml.
2. Confirm `android:requestLegacyExternalStorage` is ABSENT.
3. Confirm `android:usesCleartextTraffic="false"` is present.
4. Confirm `network_security_config.xml` exists in `res/xml/`.
5. Build release APK and run `aapt dump badging app-release.apk` — no legacy storage warning.

### TEST 15 — Duplicate Payment Prevention
1. As a fundi with an unpaid job fee, navigate to payment screen and tap submit twice quickly.
2. Check `payments` collection — only ONE document with `status = "submitted"` should exist.
3. Tap again on a second visit — `_createPayment` returns existing payment ID.

---

## WHAT WAS FIXED — SUMMARY

| # | What | Where | Impact |
|---|------|-------|--------|
| 1 | Role escalation blocked (users can't write role/plan/accountStatus) | `firestore.rules` | 🔴 Critical |
| 2 | Wallet write-protected from fundi (only admin/CF can update) | `firestore.rules` | 🔴 Critical |
| 3 | Booking field-level restrictions (client/fundi can only update their allowed fields) | `firestore.rules` | 🔴 Critical |
| 4 | Promotion no longer auto-activates; must wait for admin confirmation | `payment_service.dart`, CF `onPaymentWrite` | 🔴 Critical |
| 5 | Cross-user notifications now sent by Cloud Functions (Admin SDK) | `functions/index.js` — `onBookingWrite` | 🔴 Critical |
| 6 | Wallet lock/unlock now done by Cloud Functions (Admin SDK) | `functions/index.js` — `onBookingAcceptWallet`, `onPaymentWrite` | 🔴 Critical |
| 7 | Server-side active-job lock enforced in Firestore transaction | `booking_service.dart` — `acceptBooking()` | 🔴 Critical |
| 8 | Storage: only chat participants can upload/read chat media | `storage.rules` | 🟠 High |
| 9 | Booking expiry automation (scheduled Cloud Function, every 1h) | `functions/index.js` — `scheduledBookingExpiry` | 🟠 High |
| 10 | Subscription expiry automation (daily) | `functions/index.js` — `scheduledSubscriptionExpiry` | 🟠 High |
| 11 | Promotion expiry automation (every 6h) | `functions/index.js` — `scheduledPromotionExpiry` | 🟠 High |
| 12 | Custom Auth claims set at registration (rules use token, not Firestore lookup) | `auth_service.dart`, `setUserRoleClaim` CF | 🟠 High |
| 13 | Phone number blocking regex strengthened (dots, Unicode, all separators) | `app_utils.dart` | 🟠 High |
| 14 | Payment submit screen now shows real instructions + requires reference number | `payment_submit_screen.dart` | 🟠 High |
| 15 | Removed mock payment labels and instant-unlock messages | `payment_provider.dart` | 🟠 High |
| 16 | Toast duration increased to LENGTH_LONG | `app_utils.dart` | 🟡 Medium |
| 17 | Booking streams limited to 50 (pagination) | `booking_service.dart` | 🟡 Medium |
| 18 | Notification stream queries only unread docs (limit 100) | `notification_provider.dart` | 🟡 Medium |
| 19 | Duplicate payment prevention in `_createPayment` | `payment_service.dart` | 🟡 Medium |
| 20 | Removed `requestLegacyExternalStorage` | `AndroidManifest.xml` | 🟡 Medium |
| 21 | Added `network_security_config.xml` enforcing HTTPS | `network_security_config.xml` | 🟡 Medium |
| 22 | Added `cloud_functions` dependency | `pubspec.yaml` | 🟡 Medium |
| 23 | Added missing Firestore indexes for subscriptions/promotions expiry queries | `firestore.indexes.json` | 🟡 Medium |

---

## KNOWN REMAINING ITEMS (Phase 2)

- FCM push notifications (foreground + background) — requires server-side FCM dispatch in CF.
- Admin region reports screen.
- Admin promotions management screen.
- Subscription renewal reminders.
- Agreed price field in booking.
- Full Selcom payment integration.
- Firebase Crashlytics setup.
- Chat pagination (load-more older messages).
- Admin dashboard aggregated stats (replace full-collection streams).
