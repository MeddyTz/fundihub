import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/cards/booking_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

class FundiJobsScreen extends StatefulWidget {
  /// 0 = Requests/Pending  1 = Active  2 = History/Completed
  final int initialTab;
  const FundiJobsScreen({super.key, this.initialTab = 0});
  @override
  State<FundiJobsScreen> createState() => _FundiJobsScreenState();
}

class _FundiJobsScreenState extends State<FundiJobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Optimistic-UI set: bookingIds that the fundi just accepted.
  // Removes them from Requests tab immediately without waiting for stream.
  final Set<String> _justAccepted = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this,
        initialIndex: widget.initialTab.clamp(0, 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null && uid.isNotEmpty) {
        context.read<BookingProvider>().subscribeFundiBookings(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Status categorisation ─────────────────────────────────────────────────
  //
  // Uses AppConstants lowercase values. The BookingService._normalizeDoc() call
  // ensures all statuses are normalised before entering the model, so these
  // comparisons are reliable.

  bool _isPending(BookingModel b) =>
      b.status == AppConstants.bookingPending;

  bool _isFinished(BookingModel b) {
    final s = b.status;
    return s == AppConstants.bookingCompleted  ||
           s == AppConstants.bookingCancelled  ||
           s == AppConstants.bookingRejected   ||
           s == AppConstants.bookingExpired;
  }

  bool _isActive(BookingModel b) => !_isPending(b) && !_isFinished(b);

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<BookingProvider>();
    final l10n      = AppL10n.of(context);
    final notifProv = context.watch<NotificationProvider>();

    // Requests = pending bookings that haven't been optimistically accepted yet
    final all      = provider.bookings;
    final pending  = all
        .where((b) => _isPending(b) && !_justAccepted.contains(b.bookingId))
        .toList();
    final active   = all.where(_isActive).toList();
    final finished = all.where(_isFinished).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(l10n.myJobs,
            style: AppTextStyles.appBarTitle
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller:           _tabController,
            indicatorColor:       AppColors.white,
            indicatorWeight:      3,
            indicatorSize:        TabBarIndicatorSize.label,
            labelColor:           AppColors.white,
            unselectedLabelColor: AppColors.white.withOpacity(0.55),
            labelStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(child: _TabLabel(
                  text:     l10n.requests,
                  count:    pending.length,
                  notifDot: notifProv.bookingUnread > 0)),
              Tab(child: _TabLabel(
                  text:  l10n.active,
                  count: active.length)),
              Tab(child: _TabLabel(
                  text:      l10n.history,
                  count:     0,
                  showCount: false)),
            ],
          ),
        ),
      ),
      body: provider.isLoading
          ? ListView.builder(
              padding:     const EdgeInsets.all(AppTheme.spaceXXL),
              itemCount:   4,
              itemBuilder: (_, __) => CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // ── Requests ────────────────────────────────────────────
                _JobList(
                  bookings:    pending,
                  isClient:    false,
                  emptyIcon:   Icons.inbox_outlined,
                  emptyTitle:  'No New Requests',
                  emptySubtitle: l10n.newRequestsAppear,
                  itemBuilder: (booking) => _PendingJobTile(
                    booking:     booking,
                    onAccepted: () {
                      // Optimistic remove from Requests tab immediately
                      setState(() => _justAccepted.add(booking.bookingId));
                      // Switch to Active tab
                      _tabController.animateTo(1);
                    },
                    onTap: () => context.push(
                        '/booking/detail', extra: booking.bookingId),
                  ),
                ),
                // ── Active ───────────────────────────────────────────────
                _JobList(
                  bookings:     active,
                  isClient:     false,
                  emptyIcon:    Icons.work_outline_rounded,
                  emptyTitle:   'No Active Jobs',
                  emptySubtitle: l10n.acceptedJobsAppear,
                  itemBuilder:  (booking) => Column(children: [
                    BookingCard(
                      booking:  booking,
                      isClient: false,
                      onTap: () => context.push(
                          '/booking/detail', extra: booking.bookingId),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
                // ── History ───────────────────────────────────────────────
                _JobList(
                  bookings:     finished,
                  isClient:     false,
                  emptyIcon:    Icons.history_rounded,
                  emptyTitle:   'No Job History',
                  emptySubtitle: l10n.historyJobsAppear,
                  itemBuilder:  (booking) => Column(children: [
                    BookingCard(
                      booking:  booking,
                      isClient: false,
                      onTap: () => context.push(
                          '/booking/detail', extra: booking.bookingId),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ],
            ),
    );
  }
}

// ── Tab label ─────────────────────────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final String text;
  final int    count;
  final bool   showCount;
  final bool   notifDot;

  const _TabLabel({
    required this.text,
    required this.count,
    this.showCount = true,
    this.notifDot  = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (showCount && count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color:        AppColors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color:      AppColors.white,
                      fontSize:   10,
                      fontWeight: FontWeight.w800)),
            ),
          ],
          if (notifDot) ...[
            const SizedBox(width: 4),
            Container(
              width:  7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppColors.secondary, shape: BoxShape.circle),
            ),
          ],
        ],
      );
}

// ── Generic job list ──────────────────────────────────────────────────────────

class _JobList extends StatelessWidget {
  final List<BookingModel>      bookings;
  final bool                    isClient;
  final IconData                emptyIcon;
  final String                  emptyTitle;
  final String                  emptySubtitle;
  final Widget Function(BookingModel) itemBuilder;

  const _JobList({
    required this.bookings,
    required this.isClient,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return AppEmptyState(
        icon:      emptyIcon,
        title:     emptyTitle,
        subtitle:  emptySubtitle,
        iconColor: AppColors.grey400,
      );
    }
    return ListView.builder(
      padding:     const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount:   bookings.length,
      itemBuilder: (_, i) => itemBuilder(bookings[i]),
    );
  }
}

// ── Pending job tile with Accept / Reject ─────────────────────────────────────

class _PendingJobTile extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onAccepted;
  final VoidCallback onTap;

  const _PendingJobTile({
    required this.booking,
    required this.onAccepted,
    required this.onTap,
  });

  @override
  State<_PendingJobTile> createState() => _PendingJobTileState();
}

class _PendingJobTileState extends State<_PendingJobTile> {
  bool _busy        = false;
  bool _accepted    = false;  // local flag — prevents double-tap
  bool _rejected    = false;

  Future<void> _accept() async {
    if (_busy || _accepted || _rejected) return;
    setState(() => _busy = true);

    try {
      final ok = await context
          .read<BookingProvider>()
          .acceptBooking(widget.booking.bookingId);

      if (!mounted) return;

      if (ok) {
        HapticFeedback.mediumImpact();
        setState(() { _accepted = true; _busy = false; });

        // Mark booking notification as read
        final uid = context.read<AuthProvider>().userModel?.uid ?? '';
        context.read<NotificationService>().markBookingNotificationsRead(
          userId: uid, bookingId: widget.booking.bookingId);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         const Text('Booking accepted! Chat is now open.'),
          backgroundColor: AppColors.success,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));

        // Notify parent to remove from pending list + switch tab
        widget.onAccepted();
      } else {
        setState(() => _busy = false);
        final err = context.read<BookingProvider>().errorMessage;
        if (mounted && err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text(err),
            backgroundColor: AppColors.error,
            behavior:        SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy || _accepted || _rejected) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Booking?'),
        content: const Text(
            'This request will be rejected and the client will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<BookingProvider>().rejectBooking(
          widget.booking.bookingId);
      if (mounted) setState(() { _rejected = true; _busy = false; });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If just accepted/rejected optimistically, show a brief confirmation
    if (_accepted) {
      return Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColors.successSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border:       Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Booking accepted — moved to Active.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
    }

    if (_rejected) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColors.error.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border:       Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.cancel_rounded, color: AppColors.error.withOpacity(0.7), size: 20),
          const SizedBox(width: 10),
          Text('Booking rejected.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.error)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingCard(
          booking:  widget.booking,
          isClient: false,
          onTap:    widget.onTap,
        ),
        const SizedBox(height: 4),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child:   AppLoaderCenter(),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reject,
                  icon:      const Icon(Icons.close_rounded, size: 16),
                  label:     const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _accept,
                  icon:      const Icon(Icons.check_rounded, size: 16),
                  label:     const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation:       0,
                    padding:         const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
