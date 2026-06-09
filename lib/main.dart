import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'models/booking_model.dart';
import 'models/reel_model.dart';
import 'models/fundi_model.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/block_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/client_provider.dart';
import 'providers/fundi_provider.dart';
import 'providers/lang_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/reel_provider.dart';
import 'providers/review_provider.dart';
import 'services/auth_service.dart';
import 'services/block_service.dart';
import 'services/booking_service.dart';
import 'services/category_service.dart';
import 'services/chat_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/reel_service.dart';
import 'services/review_service.dart';
import 'services/storage_service.dart';
import 'services/user_service.dart';
import 'services/wallet_service.dart';
import 'screens/admin/admin_main_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/suspended_screen.dart';
import 'screens/client/all_categories_screen.dart';
import 'screens/client/category_fundis_screen.dart';
import 'screens/client/client_bookings_screen.dart';
import 'screens/client/client_main_shell.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/client/create_booking_screen.dart';
import 'screens/client/fundi_details_screen.dart';
import 'screens/client/fundi_by_id_screen.dart';
import 'screens/client/submit_review_screen.dart';
import 'screens/client/nearby_fundis_screen.dart';
import 'screens/fundi/fundi_jobs_screen.dart';
import 'screens/fundi/fundi_main_shell.dart';
import 'screens/fundi/fundi_profile_screen.dart';
import 'screens/fundi/fundi_promotion_screen.dart';
import 'screens/fundi/fundi_upload_reel_screen.dart';
import 'screens/fundi/fundi_wallet_screen.dart';
import 'screens/profile/client_profile_completion_screen.dart';
import 'screens/profile/fundi_profile_completion_screen.dart';
import 'screens/shared/blocked_users_screen.dart';
import 'screens/shared/booking_detail_screen.dart';
import 'screens/shared/chat_detail_screen.dart';
import 'screens/shared/chat_list_screen.dart';
import 'screens/shared/edit_profile_screen.dart';
import 'screens/shared/notifications_screen.dart';
import 'screens/shared/payment_submit_screen.dart';
import 'screens/shared/reels_screen.dart';
import 'screens/shared/saved_reels_screen.dart';
import 'screens/shared/report_user_screen.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.registerBackgroundHandler();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final langProvider = LangProvider();
  await langProvider.init();

  runApp(FundiHubApp(langProvider: langProvider));
}

class FundiHubApp extends StatelessWidget {
  final LangProvider langProvider;
  const FundiHubApp({super.key, required this.langProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LangProvider>.value(value: langProvider),

        // ── Services ────────────────────────────────────────────
        Provider<AuthService>(create:         (_) => AuthService()),
        Provider<UserService>(create:         (_) => UserService()),
        Provider<CategoryService>(create:     (_) => CategoryService()),
        Provider<WalletService>(create:       (_) => WalletService()),
        Provider<BookingService>(create:      (_) => BookingService()),
        Provider<PaymentService>(create:      (_) => PaymentService()),
        Provider<ChatService>(create:         (_) => ChatService()),
        Provider<ReviewService>(create:       (_) => ReviewService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<BlockService>(create:        (_) => BlockService()),
        Provider<LocationService>(create:     (_) => LocationService()),
        Provider<StorageService>(create:      (_) => StorageService()),
        Provider<ReelService>(create: (ctx) =>
            ReelService(storageService: ctx.read<StorageService>())),

        // ── Providers ────────────────────────────────────────────
        ChangeNotifierProxyProvider2<AuthService, UserService,
            app_auth.AuthProvider>(
          create: (ctx) => app_auth.AuthProvider(
              authService: ctx.read<AuthService>(),
              userService: ctx.read<UserService>()),
          update: (ctx, a, u, prev) =>
              prev ?? app_auth.AuthProvider(authService: a, userService: u),
        ),
        ChangeNotifierProxyProvider<CategoryService, ClientProvider>(
          create: (ctx) => ClientProvider(
            categoryService: ctx.read<CategoryService>(),
            locationService: ctx.read<LocationService>(),
          ),
          update: (ctx, c, prev) =>
              prev ??
              ClientProvider(
                categoryService: c,
                locationService: ctx.read<LocationService>(),
              ),
        ),
        ChangeNotifierProxyProvider<WalletService, FundiProvider>(
          create: (ctx) =>
              FundiProvider(walletService: ctx.read<WalletService>()),
          update: (ctx, w, prev) =>
              prev ?? FundiProvider(walletService: w),
        ),
        ChangeNotifierProxyProvider<BookingService, BookingProvider>(
          create: (ctx) =>
              BookingProvider(bookingService: ctx.read<BookingService>()),
          update: (ctx, b, prev) =>
              prev ?? BookingProvider(bookingService: b),
        ),
        ChangeNotifierProxyProvider<PaymentService, PaymentProvider>(
          create: (ctx) =>
              PaymentProvider(paymentService: ctx.read<PaymentService>()),
          update: (ctx, p, prev) =>
              prev ?? PaymentProvider(paymentService: p),
        ),
        ChangeNotifierProxyProvider<ChatService, ChatProvider>(
          create: (ctx) =>
              ChatProvider(chatService: ctx.read<ChatService>()),
          update: (ctx, c, prev) =>
              prev ?? ChatProvider(chatService: c),
        ),
        ChangeNotifierProxyProvider<ReviewService, ReviewProvider>(
          create: (ctx) =>
              ReviewProvider(reviewService: ctx.read<ReviewService>()),
          update: (ctx, r, prev) =>
              prev ?? ReviewProvider(reviewService: r),
        ),
        ChangeNotifierProxyProvider<BlockService, BlockProvider>(
          create: (ctx) =>
              BlockProvider(blockService: ctx.read<BlockService>()),
          update: (ctx, b, prev) =>
              prev ?? BlockProvider(blockService: b),
        ),

        // NotificationProvider is standalone — subscribed in _AppWithRouterState
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),

        ChangeNotifierProxyProvider2<ReelService, StorageService, ReelProvider>(
          create: (ctx) => ReelProvider(
            reelService:    ctx.read<ReelService>(),
            storageService: ctx.read<StorageService>(),
          ),
          update: (ctx, r, s, prev) =>
              prev ?? ReelProvider(reelService: r, storageService: s),
        ),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final ap = context.read<app_auth.AuthProvider>();
    _router = _buildRouter(ap);

    // ── FIX: Subscribe immediately if already authenticated ────────────────
    // addListener only fires on CHANGES. If the user is already logged in
    // when this widget mounts (app restart, hot reload), the listener would
    // never fire and the bell counter would never start.
    // We call _onAuthChange() once here to handle the current state,
    // then register the listener for future changes.
    _onAuthChange(ap);

    ap.addListener(() => _onAuthChange(ap));
  }

  /// Called once on mount (for current auth state) and on every auth change.
  void _onAuthChange(app_auth.AuthProvider ap) {
    final notifProv  = context.read<NotificationProvider>();
    final notifSvc   = context.read<NotificationService>();
    final blockProv  = context.read<BlockProvider>();

    final uid = ap.userModel?.uid ?? '';

    if (ap.isAuthenticated && uid.isNotEmpty) {
      // Start notification bell counter — covers both fundi and client
      notifProv.subscribe(uid);

      // Start FCM token registration + foreground message handling
      notifSvc.initialize(uid);

      // Start block list subscription
      blockProv.subscribe(uid);

    } else if (ap.status == app_auth.AuthStatus.unauthenticated ||
               ap.status == app_auth.AuthStatus.suspended       ||
               ap.status == app_auth.AuthStatus.error) {
      // ── FIX: Unsubscribe on logout/suspension ──────────────────────────
      notifProv.unsubscribe();
      notifSvc.dispose();
      // Note: BlockProvider handles its own cleanup on subscribe with new uid
    }
  }

  GoRouter _buildRouter(app_auth.AuthProvider ap) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: false,
      refreshListenable: ap,
      redirect: (context, state) {
        final status = ap.status;
        final loc    = state.matchedLocation;
        if (loc == '/') return null;
        final isAuth = loc == '/login'         ||
                       loc == '/register'      ||
                       loc == '/role-selection';
        switch (status) {
  case app_auth.AuthStatus.initial:
  case app_auth.AuthStatus.loading:
    return null;

  case app_auth.AuthStatus.unauthenticated:
  case app_auth.AuthStatus.error:
  case app_auth.AuthStatus.guest:
    if (!isAuth) return '/login';
    return null;

  case app_auth.AuthStatus.suspended:
    if (loc != '/suspended') return '/suspended';
    return null;

  case app_auth.AuthStatus.profileIncomplete:
    if (loc != '/profile-completion') {
      return '/profile-completion';
    }
    return null;

  case app_auth.AuthStatus.authenticated:
    if (isAuth ||
        loc == '/profile-completion' ||
        loc == '/suspended') {
      final u = ap.userModel;

      if (u == null) return '/login';

      if (u.isAdmin) return '/admin/dashboard';

      if (u.isFundi) return '/fundi/dashboard';

      return '/client/dashboard';
    }

    return null;
}
      },
      routes: [
        // ── Core ────────────────────────────────────────────────
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/role-selection', builder: (_, s) {
          final e = s.extra as Map<String, dynamic>?;
          return RoleSelectionScreen(
              email:    e?['email']    ?? '',
              password: e?['password'] ?? '');
        }),
        GoRoute(path: '/suspended', builder: (_, __) => const SuspendedScreen()),
        GoRoute(path: '/profile-completion', builder: (context, _) {
          final a = context.read<app_auth.AuthProvider>();
          if (a.userModel?.isFundi == true) {
            return const FundiProfileCompletionScreen();
          }
          return const ClientProfileCompletionScreen();
        }),

        // ── Client ──────────────────────────────────────────────
        GoRoute(
            path: '/client/dashboard',
            builder: (_, __) => const ClientMainShell()),
        GoRoute(
            path: '/client/profile',
            builder: (_, __) => const ClientProfileScreen()),
        GoRoute(
            path: '/client/fundi-details',
            builder: (_, s) =>
                FundiDetailsScreen(fundi: s.extra as FundiModel)),
        GoRoute(
            path: '/client/fundi-by-id',
            builder: (_, s) =>
                FundiByIdScreen(fundiId: s.extra as String)),
        GoRoute(
            path: '/client/bookings',
            builder: (_, __) => const ClientBookingsScreen()),
        GoRoute(
            path: '/client/submit-review',
            builder: (_, s) =>
                SubmitReviewScreen(booking: s.extra as BookingModel)),
        GoRoute(
            path: '/client/all-categories',
            builder: (_, s) =>
                AllCategoriesScreen(initialCategory: s.extra as String?)),
        GoRoute(
            path: '/client/category-fundis',
            builder: (_, s) =>
                CategoryFundisScreen(category: s.extra as String)),

        // ── Booking ─────────────────────────────────────────────
        GoRoute(
            path: '/booking/create',
            builder: (_, s) =>
                CreateBookingScreen(fundi: s.extra as FundiModel)),
        GoRoute(
            path: '/booking/detail',
            builder: (_, s) =>
                BookingDetailScreen(bookingId: s.extra as String)),

        // ── Fundi ───────────────────────────────────────────────
        GoRoute(
            path: '/fundi/dashboard',
            builder: (_, __) => const FundiMainShell()),
        GoRoute(
            path: '/fundi/jobs',
            builder: (_, __) => const FundiJobsScreen()),
        GoRoute(
            path: '/fundi/wallet',
            builder: (_, __) => const FundiWalletScreen()),
        GoRoute(
            path: '/fundi/promotion',
            builder: (_, __) => const FundiPromotionScreen()),
        GoRoute(
            path: '/fundi/profile',
            builder: (_, __) => const FundiProfileScreen()),
        GoRoute(
            path: '/fundi/upload-reel',
            builder: (_, __) => const FundiUploadReelScreen()),

        // ── Reels ────────────────────────────────────────────────
        GoRoute(
          path: '/reels',
          builder: (_, state) {
            final extra  = state.extra as Map<String, dynamic>?;
            final fList  = extra?['fundiReelsList'] as List<ReelModel>?;
            final idx    = (extra?['initialIndex'] as int?) ?? 0;
            return ReelsScreen(
              fundiReelsList: fList,
              initialIndex:   idx,
            );
          },
        ),
        GoRoute(path: '/saved-reels', builder: (_, __) => const SavedReelsScreen()),

        // ── Payment ─────────────────────────────────────────────
        GoRoute(path: '/payment/submit', builder: (_, s) {
          final e = s.extra as Map<String, dynamic>;
          return PaymentSubmitScreen(
            type:             e['type']             as PaymentSubmitType,
            amount:           e['amount']           as int?,
            durationDays:     e['durationDays']     as int?,
            relatedBookingId: e['relatedBookingId'] as String?,
          );
        }),

        // ── Chat ────────────────────────────────────────────────
        GoRoute(
            path: '/chat/list',
            builder: (_, __) => const ChatListScreen()),
        GoRoute(
            path: '/chat/detail',
            builder: (_, s) =>
                ChatDetailScreen(chatId: s.extra as String)),

        // ── Shared ──────────────────────────────────────────────
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen()),
        GoRoute(
            path: '/edit-profile',
            builder: (_, __) => const EditProfileScreen()),
        GoRoute(
            path: '/blocked-users',
            builder: (_, __) => const BlockedUsersScreen()),
        GoRoute(path: '/report', builder: (_, s) {
          final e = s.extra as Map<String, dynamic>;
          return ReportUserScreen(
            reportedUserId:   e['userId']    as String,
            reportedUserName: e['userName']  as String,
            relatedBookingId: e['bookingId'] as String?,
          );
        }),

        // ── Nearby ──────────────────────────────────────────────
        GoRoute(
            path: '/client/nearby',
            builder: (_, __) => const NearbyFundisScreen()),

        // ── Admin ────────────────────────────────────────────────
        GoRoute(
            path: '/admin/dashboard',
            builder: (_, __) => const AdminMainShell()),
      ],
      errorBuilder: (ctx, s) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Page not found'),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => ctx.go('/'),
                  child: const Text('Go Home')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangProvider>();
    return MaterialApp.router(
      title:                      'FundiHub',
      debugShowCheckedModeBanner: false,
      locale:                     lang.locale,
      supportedLocales: const [Locale('en'), Locale('sw')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme:        AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
