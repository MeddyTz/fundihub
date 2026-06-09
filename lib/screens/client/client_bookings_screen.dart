import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/cards/booking_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_shimmer.dart';

class ClientBookingsScreen extends StatefulWidget {
  // TASK 6: optional initial tab (0=Pending, 1=Active, 2=History)
  final int initialTab;
  const ClientBookingsScreen({super.key, this.initialTab = 0});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this,
        initialIndex: widget.initialTab.clamp(0, 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) {
        context.read<BookingProvider>().subscribeClientBookings(uid);
      }
      _tab.addListener(_onTabChanged);
    });
  }

  void _onTabChanged() {
    // When user opens the Active tab, mark all booking notifications read
    if (!_tab.indexIsChanging && _tab.index == 1) {
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null && uid.isNotEmpty) {
        context.read<NotificationService>().markAllRead(uid).ignore();
      }
    }
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final l10n = AppL10n.of(context);
    final notifProv = context.watch<NotificationProvider>();
    final pending = provider.bookings.where((b) => b.isPending).toList();
    final active = provider.bookings.where((b) => b.isActive).toList();
    final finished = provider.bookings.where((b) => b.isFinished).toList();

    // Booking-type notification badge for the "Active" tab (accepted, agreement etc.)
    final bookingNotifCount = notifProv.bookingUnread;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.myBookings),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.6),
          labelStyle: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(
              child: _TabLabel(
                text: l10n.pending,
                count: pending.length,
                badgeColor: AppColors.warning,
              ),
            ),
            Tab(
              child: _TabLabel(
                text: l10n.active,
                count: active.isNotEmpty ? active.length : 0,
                // Show orange badge when booking notifications are unread
                badgeColor: bookingNotifCount > 0
                    ? AppColors.secondary
                    : AppColors.primary,
                extraBadge: bookingNotifCount > 0 ? bookingNotifCount : 0,
              ),
            ),
            Tab(
              child: _TabLabel(
                text: l10n.history,
                count: finished.length,
                badgeColor: AppColors.grey500,
                showCount: false,
              ),
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? _shimmer()
          : TabBarView(
              controller: _tab,
              children: [
                _List(
                  bookings: pending,
                  isClient: true,
                  onTap: (b) =>
                      context.push('/booking/detail', extra: b.bookingId),
                  emptyIcon: Icons.pending_outlined,
                  emptyTitle: l10n.sw ? 'Hakuna Maombi Yanayosubiri' : 'No Pending Bookings',
                  emptySubtitle: l10n.bookingRequestsAppear,
                ),
                _List(
                  bookings: active,
                  isClient: true,
                  onTap: (b) =>
                      context.push('/booking/detail', extra: b.bookingId),
                  emptyIcon: Icons.work_outline,
                  emptyTitle: l10n.sw ? 'Hakuna Kazi Zinazoendelea' : 'No Active Bookings',
                  emptySubtitle:
                      'Accepted and in-progress bookings appear here.',
                ),
                _List(
                  bookings: finished,
                  isClient: true,
                  onTap: (b) =>
                      context.push('/booking/detail', extra: b.bookingId),
                  emptyIcon: Icons.history_rounded,
                  emptyTitle: l10n.sw ? 'Bado Hakuna Historia' : 'No History Yet',
                  emptySubtitle:
                      'Completed and cancelled bookings will appear here.',
                  showReviewPrompt: true,
                ),
              ],
            ),
    );
  }

  Widget _shimmer() => ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceXXL),
        itemCount: 4,
        itemBuilder: (_, __) => AppShimmer(
          child: Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            ),
          ),
        ),
      );
}

// ─── Tab label with optional count badge ─────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final String text;
  final int count;
  final Color badgeColor;
  final bool showCount;
  final int extraBadge;

  const _TabLabel({
    required this.text,
    required this.count,
    required this.badgeColor,
    this.showCount = true,
    this.extraBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final show = showCount && count > 0;
    final showExtra = extraBadge > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (show) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (showExtra) ...[
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Booking list ─────────────────────────────────────────────────────────────

class _List extends StatelessWidget {
  final List<BookingModel> bookings;
  final bool isClient;
  final void Function(BookingModel) onTap;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showReviewPrompt;

  const _List({
    required this.bookings,
    required this.isClient,
    required this.onTap,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.showReviewPrompt = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        iconColor: AppColors.grey400,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceXXL),
      itemCount: bookings.length,
      itemBuilder: (_, i) {
        final booking = bookings[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingCard(
              booking: booking,
              isClient: isClient,
              onTap: () => onTap(booking),
            ),
            if (showReviewPrompt && booking.isCompleted)
              _HistoryReviewPrompt(booking: booking),
            const SizedBox(height: AppTheme.spaceMD),
          ],
        );
      },
    );
  }
}

// ─── Review prompt ────────────────────────────────────────────────────────────

class _HistoryReviewPrompt extends StatelessWidget {
  final BookingModel booking;
  const _HistoryReviewPrompt({required this.booking});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final clientId = context.read<AuthProvider>().userModel?.uid ?? '';
    if (clientId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: context
          .read<ReviewProvider>()
          .hasReviewedStream(booking.bookingId, clientId),
      initialData: false,
      builder: (context, snapshot) {
        final reviewed = snapshot.data ?? false;

        return Container(
          margin: const EdgeInsets.only(top: AppTheme.spaceSM),
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            color: reviewed
                ? AppColors.successSurface
                : AppColors.premium.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: reviewed
                  ? AppColors.success.withOpacity(0.25)
                  : AppColors.premium.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                reviewed ? Icons.task_alt_rounded : Icons.star_rounded,
                color: reviewed ? AppColors.success : AppColors.premium,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  reviewed
                      ? 'Review submitted'
                      : 'Help other clients by rating ${booking.fundiName}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        reviewed ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ),
              if (!reviewed)
                TextButton(
                  onPressed: () =>
                      context.push('/client/submit-review', extra: booking),
                  child: Text(l10n.rate),
                ),
            ],
          ),
        );
      },
    );
  }
}
