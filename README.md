# FundiHub — Complete App (All Phases 1–10)

## 🏗️ Tech Stack
Flutter · Firebase Auth · Cloud Firestore · Firebase Storage · FCM · Provider · GoRouter

## 📋 Phases Included
- **Phase 1:** Setup, Theme, Constants, Routing, Firebase Init
- **Phase 2:** Auth, Role Selection, Profile Completion, GoRouter redirect
- **Phase 3:** Client & Fundi Dashboards, Category System, Fundi Cards
- **Phase 4:** Booking System (create → accept → agree → in-progress → complete)
- **Phase 5:** Payment System (job fee, premium subscription, promotions)
- **Phase 6:** Real-time Chat (text/image/voice/location, typing, seen/delivered)
- **Phase 7:** Reviews, Ratings & Report User
- **Phase 8:** Profile Screens (client & fundi)
- **Phase 9:** Admin Dashboard (payments confirm/reject, user management)
- **Phase 10:** Production Firestore Rules, Storage Rules, Indexes

## 🚀 Setup Instructions
1. Create a Firebase project at console.firebase.google.com
2. Enable: Authentication (Email/Password), Firestore, Storage
3. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
4. Run: `flutterfire configure` to generate firebase_options.dart
5. Run: `flutter pub get`
6. Run: `flutter run`

## 👤 Admin Setup
1. Register normally with any email
2. In Firestore Console → users → [your uid], set:
   - `role` = `admin`
   - `isProfileComplete` = `true`
3. Re-login → routed to Admin Dashboard

## 💰 Business Rules
- Free fundis: Tsh 2,500 per completed job, locked until fee paid
- Premium: Tsh 35,000/month, unlimited jobs, no per-job fees
- Promotions: 7d=Tsh 5,000 / 14d=Tsh 9,000 / 30d=Tsh 15,000
- Payment via M-Pesa to company number: **123456**
- Admin manually confirms or rejects all payments

## 📁 Project Structure
```
lib/
├── core/constants/     — AppConstants, RouteConstants, FirestoreConstants
├── core/theme/         — AppColors, AppTextStyles, AppTheme
├── core/utils/         — Validators, AppUtils
├── models/             — UserModel, FundiModel, BookingModel, MessageModel, etc.
├── services/           — AuthService, BookingService, ChatService, etc.
├── providers/          — AuthProvider, BookingProvider, ChatProvider, etc.
├── screens/
│   ├── auth/           — Login, Register, RoleSelection, Suspended
│   ├── profile/        — ClientProfileCompletion, FundiProfileCompletion
│   ├── client/         — Dashboard, Bookings, FundiDetails, CreateBooking, etc.
│   ├── fundi/          — Dashboard, Jobs, Wallet, Promotion, Profile
│   ├── admin/          — Dashboard, Payments, Users
│   └── shared/         — BookingDetail, PaymentSubmit, ChatList, ChatDetail, Report
└── widgets/
    ├── cards/          — FundiCard, BookingCard, PaymentCard
    ├── chat/           — ChatBubble, ChatInputBar, ChatDateDivider
    ├── common/         — AppButton, AppTextField, AppAvatar, AppBadge, etc.
    ├── dashboard/      — ClientSearchBar, PromotedFundisSection
    └── auth/           — AuthHeader
```
