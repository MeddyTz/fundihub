# FundiHub — Complete Step-by-Step Setup Guide

## ─────────────────────────────────────────
## PART 1: INSTALL REQUIRED TOOLS
## ─────────────────────────────────────────

### Step 1 — Install Flutter SDK
1. Go to: https://docs.flutter.dev/get-started/install
2. Download for your OS (Windows / macOS / Linux)
3. Extract and add to PATH as instructed
4. Run: flutter doctor
   ✅ Fix any issues shown before continuing

### Step 2 — Install Android Studio
1. Go to: https://developer.android.com/studio
2. Install Android Studio
3. Open Android Studio → More Actions → SDK Manager
4. Install: Android SDK, Android SDK Platform-Tools
5. Create a virtual device: More Actions → Virtual Device Manager → Create Device
   - Choose: Pixel 6 → API 33 (Android 13) → Finish

### Step 3 — Install VS Code (Recommended Editor)
1. Go to: https://code.visualstudio.com
2. Install the Flutter extension (by Dart Code)
3. Install the Dart extension

### Step 4 — Install Node.js
1. Go to: https://nodejs.org
2. Download LTS version
3. Verify: node --version

### Step 5 — Install Firebase CLI
   npm install -g firebase-tools
   firebase login
   (Opens browser — log in with your Google account)

### Step 6 — Install FlutterFire CLI
   dart pub global activate flutterfire_cli

## ─────────────────────────────────────────
## PART 2: CREATE FIREBASE PROJECT
## ─────────────────────────────────────────

### Step 7 — Create Firebase Project
1. Go to: https://console.firebase.google.com
2. Click Add project
3. Name it: fundihub (or anything you like)
4. Disable Google Analytics (can enable later)
5. Click Create project

### Step 8 — Enable Authentication
1. Firebase Console → Authentication → Get started
2. Sign-in method tab → Email/Password → Enable → Save

### Step 9 — Enable Firestore Database
1. Firebase Console → Firestore Database → Create database
2. Start in production mode
3. Region: europe-west1 (closest to Tanzania)
4. Click Done

### Step 10 — Enable Firebase Storage
1. Firebase Console → Storage → Get started
2. Start in production mode → Same region → Done

### Step 11 — Enable Cloud Messaging (FCM)
1. Firebase Console → Project Settings (gear icon) → Cloud Messaging tab
2. Note the Server key (for sending push notifications later)

## ─────────────────────────────────────────
## PART 3: CONNECT APP TO FIREBASE
## ─────────────────────────────────────────

### Step 12 — Open the Project
1. Extract the ZIP file
2. Open VS Code → File → Open Folder → select the fundihub folder
3. Open terminal in VS Code (Ctrl+` or Terminal → New Terminal)

### Step 13 — Install Flutter packages
   flutter pub get

### Step 14 — Connect to Firebase
   flutterfire configure
   
   When prompted:
   - Select your Firebase project: fundihub
   - Select platforms: android, ios (press Space to select, Enter to confirm)
   - This auto-creates lib/firebase_options.dart ✅

### Step 15 — Add Android config file
1. Firebase Console → Project Settings → General
2. Scroll to Your apps → click the Android icon
3. Register with package name: com.fundihub.app
4. Click Register app
5. Download google-services.json
6. Place it at: android/app/google-services.json
   (NOT android/google-services.json — must be inside app/)

### Step 16 — Add iOS config file (skip if Android only)
1. Firebase Console → Project Settings → General
2. Click Add app → iOS icon  
3. Bundle ID: com.fundihub.app
4. Download GoogleService-Info.plist
5. Open Xcode: open ios/Runner.xcworkspace
6. Drag GoogleService-Info.plist → Runner folder in Xcode
7. Check "Copy items if needed" → Finish

## ─────────────────────────────────────────
## PART 4: DEPLOY FIREBASE CONFIGURATION
## ─────────────────────────────────────────

### Step 17 — Deploy Firestore Security Rules
   firebase deploy --only firestore:rules

### Step 18 — Deploy Firestore Indexes
   firebase deploy --only firestore:indexes
   
   ⚠️ Wait 5–10 minutes for indexes to build before testing the app

### Step 19 — Deploy Storage Rules
   firebase deploy --only storage

## ─────────────────────────────────────────
## PART 5: RUN THE APP
## ─────────────────────────────────────────

### Step 20 — Start the Android Emulator
1. Android Studio → Virtual Device Manager → Start your Pixel 6 emulator
   OR plug in a physical Android device with USB debugging enabled

### Step 21 — Run the App
   flutter run
   
   First run takes 2–3 minutes to compile.
   You should see the FundiHub splash screen.

## ─────────────────────────────────────────
## PART 6: CREATE ADMIN ACCOUNT
## ─────────────────────────────────────────

### Step 22 — Register Admin
1. Open the app → Register with your email (e.g. admin@fundihub.co.tz)
2. Choose Client role (doesn't matter — we'll override)
3. Fill in the profile form
4. You'll land on the Client Dashboard

### Step 23 — Promote to Admin in Firestore
1. Go to: Firebase Console → Firestore Database
2. Click users collection → find your user document (look for your email)
3. Click the pencil/edit icon
4. Change role field: client → admin
5. Change isProfileComplete field: false → true
6. Click Update

### Step 24 — Re-login as Admin
1. In the app: Profile tab → Sign Out
2. Log back in with the same email
3. You'll now see the Admin Dashboard ✅

## ─────────────────────────────────────────
## PART 7: TEST THE APP
## ─────────────────────────────────────────

### Test as Client:
1. Register new account → Select Client
2. Complete profile → Browse fundis on dashboard
3. Tap a fundi → Book → Fill form → Send
4. Check Bookings tab for your booking

### Test as Fundi:
1. Register second account → Select Fundi
2. Complete profile (pick a category, add skills)
3. Jobs tab → Requests → Accept the client booking
4. In Booking Detail → both tap "I Agree"
5. Phone numbers become visible ✅
6. Fundi taps Mark In Progress → then Mark Complete
7. Wallet tab shows Tsh 2,500 fee due

### Test as Admin:
1. Log in with admin account
2. Payments tab → Confirm the fundi fee payment
3. Fundi wallet unlocks automatically ✅

## ─────────────────────────────────────────
## PART 8: BUILD FOR RELEASE
## ─────────────────────────────────────────

### Android Release APK (for testing):
   flutter build apk --release

### Android App Bundle (for Play Store):
   flutter build appbundle --release
   Output: build/app/outputs/bundle/release/app-release.aab

### iOS Release (requires Mac + Xcode):
   flutter build ios --release
   Then archive in Xcode → Distribute to App Store

## ─────────────────────────────────────────
## COMMON ISSUES & FIXES
## ─────────────────────────────────────────

Issue: "No Firebase App has been created"
Fix: Run flutterfire configure again — ensure firebase_options.dart was generated

Issue: "Permission denied" on Firestore queries
Fix: firebase deploy --only firestore:rules

Issue: App shows blank screen or crashes immediately
Fix: Ensure google-services.json is at android/app/google-services.json (not android/)

Issue: "Index not ready" or "The query requires an index"
Fix: firebase deploy --only firestore:indexes — then wait 10 minutes

Issue: Images not uploading
Fix: firebase deploy --only storage

Issue: Location not working on Android emulator
Fix: In emulator: three dots → Location → set a custom location

Issue: FCM notifications not received
Fix: Physical device required — FCM doesn't work on most emulators

Issue: flutter pub get fails with version conflicts
Fix: Run: flutter clean && flutter pub get

## ─────────────────────────────────────────
## BUSINESS RULES REFERENCE
## ─────────────────────────────────────────

| Rule                    | Detail                                      |
|-------------------------|---------------------------------------------|
| Free fundi job fee      | Tsh 2,500 after each completed job          |
| Premium plan            | Tsh 35,000/month — no per-job fees          |
| Job lock (active)       | Free fundi locked after accepting 1 job     |
| Job lock (fee unpaid)   | Locked again after completion until fee paid|
| Contact unlock          | Phone numbers shown after both agree        |
| Phone blocking in chat  | Can't send phone before agreement           |
| Payment number          | 123456 (M-Pesa / company number)            |
| Promotion: 7 days       | Tsh 5,000                                   |
| Promotion: 14 days      | Tsh 9,000                                   |
| Promotion: 30 days      | Tsh 15,000                                  |
| Admin confirms payments | Manual review — no auto-confirmation        |
| Block user              | Via chat menu or profile — reversible       |

## ─────────────────────────────────────────
## SUPPORT
## ─────────────────────────────────────────
Email: support@fundihub.co.tz
