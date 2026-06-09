import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/app_loading_overlay.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _State();
}

class _State extends State<BookingDetailScreen> {
  bool _notifMarked = false;

  @override
  void initState() {
    super.initState();
    context.read<BookingProvider>().subscribeBooking(widget.bookingId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markNotifs());
  }

  Future<void> _markNotifs() async {
    if (_notifMarked) return;
    _notifMarked = true;
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      await context.read<NotificationService>().markBookingNotificationsRead(
            userId: uid, bookingId: widget.bookingId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<BookingProvider>();
    final booking  = provider.selectedBooking;
    final isClient = auth.userModel?.isClient ?? true;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Detail'),
            backgroundColor: AppColors.primary),
        body: const Center(child: AppLoaderCenter()),
      );
    }

    // ── Contact / Chat visibility (NEW RULE) ──────────────────────────────
    // showContact = immediately after fundi accepts — no agreement required
    final showContact = booking.shouldShowContact && !booking.isFinished;
    final showChat    = booking.shouldShowChat    && !booking.isFinished;

    final otherName     = isClient ? booking.fundiName     : booking.clientName;
    final otherPhone    = isClient ? booking.fundiPhone    : booking.clientPhone;
    final otherImage    = isClient ? booking.fundiProfileImage : booking.clientProfileImage;
    final otherSubtitle = isClient ? booking.fundiCategory : 'Client';

    return AppLoadingOverlay(
      isLoading: provider.isSubmitting,
      message:   'Updating booking...',
      loaderType: 'booking',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Booking Detail'),
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceXXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Status banner ──────────────────────────────────────────
              _StatusBanner(booking: booking, isClient: isClient),
              const SizedBox(height: AppTheme.spaceXXL),

              // ── Person card ────────────────────────────────────────────
              _PersonCard(
                label:       isClient ? 'Fundi' : 'Client',
                name:        otherName,
                imageUrl:    otherImage,
                subtitle:    otherSubtitle,
                phone:       showContact ? otherPhone : null,
                phoneHidden: !booking.isFinished && !showContact,
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // ── Service details ────────────────────────────────────────
              _DetailCard(
                icon:    Icons.description_outlined,
                title:   'Service Description',
                content: booking.serviceDescription,
              ),
              const SizedBox(height: AppTheme.spaceXL),
              _DetailCard(
                icon:    Icons.location_on_outlined,
                title:   'Job Location',
                content: _fmtLocation(booking),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // ── Timeline ───────────────────────────────────────────────
              _Timeline(booking: booking),
              const SizedBox(height: AppTheme.spaceXXL),

              // ── Chat button ────────────────────────────────────────────
              if (showChat) ...[
                ElevatedButton.icon(
                  icon:  const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Open Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                  ),
                  onPressed: () => context.push(
                    '/chat/detail',
                    extra: booking.chatId ?? booking.bookingId,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),
              ],

              // ── Call + WhatsApp ────────────────────────────────────────
              if (showContact) ...[
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon:  const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD)),
                      ),
                      onPressed: () => _launchPhone(otherPhone),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon:  const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD)),
                      ),
                      onPressed: () => _launchWhatsApp(otherPhone),
                    ),
                  ),
                ]),
                const SizedBox(height: AppTheme.spaceXXL),
              ] else if (!booking.isFinished && booking.isPending) ...[
                // Pending — show contact-unlock hint
                _InfoBanner(
                  icon:    Icons.info_outline,
                  color:   AppColors.primary,
                  message: 'You can contact each other once the booking is accepted.',
                ),
                const SizedBox(height: AppTheme.spaceXXL),
              ],

              // ── Awaiting confirmation — client action card ─────────────
              if (booking.isAwaitingConfirmation && isClient)
                _ConfirmCompletionCard(
                    booking: booking, provider: provider),

              // ── Dispute submitted — info ───────────────────────────────
              if (booking.isCompletionDisputed) ...[
                _InfoBanner(
                  icon:    Icons.warning_amber_rounded,
                  color:   AppColors.warning,
                  message: 'Dispute submitted. Our team will review and assist.',
                ),
                const SizedBox(height: AppTheme.spaceMD),
              ],

              // ── Review (client, completed) ─────────────────────────────
              if (booking.isCompleted && isClient) ...[
                _ReviewCard(booking: booking),
                const SizedBox(height: AppTheme.spaceMD),
              ],

              // ── Report ─────────────────────────────────────────────────
              if (!booking.isFinished) ...[
                AppButton(
                  label:       'Report ${isClient ? 'Fundi' : 'Client'}',
                  type:        AppButtonType.text,
                  leadingIcon: Icons.flag_outlined,
                  onPressed:   () => context.push('/report', extra: {
                    'userId':   isClient ? booking.fundiId  : booking.clientId,
                    'userName': isClient ? booking.fundiName : booking.clientName,
                    'bookingId': booking.bookingId,
                  }),
                ),
                const SizedBox(height: AppTheme.spaceMD),
              ],

              // ── Action buttons ─────────────────────────────────────────
              _ActionButtons(
                  booking: booking,
                  isClient: isClient,
                  provider: provider),

              const SizedBox(height: AppTheme.space3XL),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtLocation(BookingModel b) {
    final parts = <String>[
      if (b.locationArea.trim().isNotEmpty) b.locationArea,
      b.locationDistrict,
      b.locationRegion,
    ];
    final det = b.locationDetails;
    return det != null && det.trim().isNotEmpty
        ? '${parts.join(', ')}\n$det'
        : parts.join(', ');
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: AppUtils.normalizePhone(phone));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      AppUtils.showSnackBar(context, 'Could not open phone app', isError: true);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) {
      if (mounted) {
        AppUtils.showSnackBar(
            context, 'Phone number not available.', isError: true);
      }
      return;
    }

    // Normalise to international format without leading +
    // Handles: 07XXXXXXXX  → 2557XXXXXXXX
    //          +2557...    → 2557...
    //          2557...     → 2557...
    String number = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    if (number.startsWith('0')) {
      number = '255${number.substring(1)}';
    }
    // strip leading + if somehow still present after digit-only extraction
    // (already stripped above, but defensive)

    debugPrint('[WhatsApp] launching for number: $number');

    // Attempt 1: whatsapp:// deep-link (opens WhatsApp app directly)
    // We do NOT use canLaunchUrl here — it returns false on Android 11+
    // unless <queries> is declared, which we now have in AndroidManifest.xml.
    // We use try/catch as the reliable fallback mechanism.
    final appUri = Uri.parse('whatsapp://send?phone=$number');
    try {
      final launched = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // WhatsApp not installed or URI not handled — fall through
    }

    // Attempt 2: https://wa.me/ — opens in browser or prompts WhatsApp install
    final webUri = Uri.parse('https://wa.me/$number');
    try {
      final launched = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // Browser also failed — fall through
    }

    // Both failed
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        'Could not open WhatsApp. Please open WhatsApp manually and message: +$number',
        isError: true,
      );
    }
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final BookingModel booking;
  final bool isClient;
  const _StatusBanner({required this.booking, required this.isClient});

  IconData _icon() {
    switch (booking.status) {
      case AppConstants.bookingPending:              return Icons.schedule_rounded;
      case AppConstants.bookingAccepted:             return Icons.check_circle_outline;
      case AppConstants.bookingAgreementConfirmed:   return Icons.handshake_outlined;
      case AppConstants.bookingInProgress:           return Icons.construction_rounded;
      case AppConstants.bookingAwaitingConfirmation: return Icons.hourglass_top_rounded;
      case AppConstants.bookingCompletionDisputed:   return Icons.warning_amber_rounded;
      case AppConstants.bookingCompleted:            return Icons.task_alt_rounded;
      case AppConstants.bookingRejected:             return Icons.block_rounded;
      case AppConstants.bookingCancelled:            return Icons.cancel_outlined;
      default:                                       return Icons.info_outline;
    }
  }

  String _message() {
    switch (booking.status) {
      case AppConstants.bookingPending:
        return isClient
            ? 'Waiting for fundi to respond. You can cancel anytime.'
            : 'New booking request. Accept or reject below.';
      case AppConstants.bookingAccepted:
        return 'Booking accepted! You can now call, WhatsApp, and chat each other.';
      case AppConstants.bookingAgreementConfirmed:
        return 'Agreement confirmed. Contact and chat are unlocked.';
      case AppConstants.bookingInProgress:
        return 'Job is currently in progress.';
      case AppConstants.bookingAwaitingConfirmation:
        return isClient
            ? 'Fundi marked the job as done. Please confirm completion or report a problem.'
            : 'Waiting for client to confirm completion.';
      case AppConstants.bookingCompletionDisputed:
        return 'A problem was reported. Our team will review and assist.';
      case AppConstants.bookingCompleted:
        return 'Job completed on ${AppUtils.formatDate(booking.completedAt ?? booking.updatedAt)}.';
      case AppConstants.bookingRejected:
        return booking.rejectionReason ?? 'Booking rejected.';
      case AppConstants.bookingCancelled:
        return booking.cancellationReason ?? 'Booking cancelled.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.getBookingStatusColor(booking.status);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding:    const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(_icon(), color: color, size: 24),
        ),
        const SizedBox(width: AppTheme.spaceMD),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppUtils.getBookingStatusDisplay(booking.status),
                style: AppTextStyles.titleMedium.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(_message(), style: AppTextStyles.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

// ─── Confirm completion card (client) ────────────────────────────────────────

class _ConfirmCompletionCard extends StatefulWidget {
  final BookingModel booking;
  final BookingProvider provider;
  const _ConfirmCompletionCard({required this.booking, required this.provider});

  @override
  State<_ConfirmCompletionCard> createState() => _ConfirmCompletionCardState();
}

class _ConfirmCompletionCardState extends State<_ConfirmCompletionCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:   const EdgeInsets.only(bottom: AppTheme.spaceXXL),
      padding:  const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color:        AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border:       Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: AppTheme.spaceSM),
          Text('Fundi marked job as done',
              style: AppTextStyles.titleSmall
                  .copyWith(color: AppColors.success)),
        ]),
        const SizedBox(height: AppTheme.spaceMD),
        Text(
          'Please confirm the job is complete, or report a problem if something is wrong.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon:  const Icon(Icons.check_rounded, size: 16),
              label: const Text('Confirm Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
              ),
              onPressed: () async {
                final confirm = await AppUtils.showConfirmDialog(
                  context,
                  title:       'Confirm Completion?',
                  message:     'Are you satisfied with the job? This will mark it as completed.',
                  confirmText: 'Yes, Complete',
                );
                if (confirm == true && mounted) {
                  final ok = await widget.provider
                      .clientConfirmCompletion(widget.booking.bookingId);
                  if (!ok && context.mounted) {
                    AppUtils.showSnackBar(context,
                        widget.provider.errorMessage ?? 'Failed',
                        isError: true);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: OutlinedButton.icon(
              icon:  const Icon(Icons.flag_rounded, size: 16),
              label: const Text('Report Problem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
              ),
              onPressed: () => _showDisputeDialog(context),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _showDisputeDialog(BuildContext ctx) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('Report a Problem'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Describe the issue with this job completion:'),
          const SizedBox(height: AppTheme.spaceMD),
          TextField(
            controller:  ctrl,
            maxLines:    3,
            decoration:  const InputDecoration(
              hintText: 'e.g. Work is incomplete, materials not replaced...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:     const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty && mounted) {
      final ok = await widget.provider.disputeCompletion(
          widget.booking.bookingId, reason: reason);
      if (!ok && context.mounted) {
        AppUtils.showSnackBar(context,
            widget.provider.errorMessage ?? 'Failed', isError: true);
      }
    }
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final BookingModel    booking;
  final bool            isClient;
  final BookingProvider provider;
  const _ActionButtons(
      {required this.booking, required this.isClient, required this.provider});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (isClient) {
      // Cancel (pending or accepted only)
      if (booking.isPending || booking.isAccepted) {
        actions.add(AppButton(
          label:       'Cancel Booking',
          type:        AppButtonType.outline,
          leadingIcon: Icons.cancel_outlined,
          onPressed:   () async {
            final ok = await AppUtils.showConfirmDialog(context,
                title:       'Cancel Booking?',
                message:     'Are you sure you want to cancel this booking?',
                confirmText: 'Cancel Booking',
                isDanger:    true);
            if (ok == true) {
              await provider.cancelBooking(booking.bookingId,
                  cancelledBy: 'client', reason: 'Client cancelled');
              if (context.mounted) context.pop();
            }
          },
        ));
      }
    } else {
      // Fundi actions
      if (booking.isPending) {
        actions.addAll([
          AppButton(
            label:       'Accept Job',
            leadingIcon: Icons.check_rounded,
            onPressed:   () => provider.acceptBooking(booking.bookingId),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          AppButton(
            label:       'Reject Job',
            type:        AppButtonType.outline,
            leadingIcon: Icons.close_rounded,
            onPressed:   () async {
              final ok = await AppUtils.showConfirmDialog(context,
                  title:       'Reject Job?',
                  message:     'Reject this booking request?',
                  confirmText: 'Reject',
                  isDanger:    true);
              if (ok == true) {
                await provider.rejectBooking(booking.bookingId,
                    reason: 'Not available');
              }
            },
          ),
        ]);
      }

      // Start job — fundi can start after accept or agreement
      if (booking.isAccepted || booking.isAgreementConfirmed) {
        if (actions.isNotEmpty) actions.add(const SizedBox(height: AppTheme.spaceMD));
        actions.add(AppButton(
          label:       'Start Job',
          leadingIcon: Icons.construction_rounded,
          onPressed:   () => provider.markInProgress(booking.bookingId),
        ));
      }

      // Mark job done (requestCompletion)
      if (booking.isInProgress) {
        if (actions.isNotEmpty) actions.add(const SizedBox(height: AppTheme.spaceMD));
        actions.add(AppButton(
          label:       'Mark Job Done',
          leadingIcon: Icons.task_alt_rounded,
          onPressed:   () async {
            final ok = await AppUtils.showConfirmDialog(context,
                title:       'Mark Job Done?',
                message:     'This will ask the client to confirm completion. You can still chat if needed.',
                confirmText: 'Mark Done');
            if (ok == true) {
              await provider.requestCompletion(booking.bookingId);
            }
          },
        ));
      }

      // Awaiting confirmation — fundi sees waiting message
      if (booking.isAwaitingConfirmation) {
        if (actions.isNotEmpty) actions.add(const SizedBox(height: AppTheme.spaceMD));
        actions.add(_InfoBanner(
          icon:    Icons.hourglass_top_rounded,
          color:   AppColors.primary,
          message: 'Waiting for client to confirm completion.',
        ));
      }

      // Cancel job (accepted, agreement, in-progress)
      if (booking.isAccepted || booking.isAgreementConfirmed || booking.isInProgress) {
        if (actions.isNotEmpty) actions.add(const SizedBox(height: AppTheme.spaceMD));
        actions.add(AppButton(
          label:       'Cancel Job',
          type:        AppButtonType.outline,
          leadingIcon: Icons.cancel_outlined,
          onPressed:   () async {
            final ok = await AppUtils.showConfirmDialog(context,
                title:       'Cancel Job?',
                message:     'Are you sure you want to cancel this job?',
                confirmText: 'Cancel Job',
                isDanger:    true);
            if (ok == true) {
              await provider.cancelBooking(booking.bookingId,
                  cancelledBy: 'fundi', reason: 'Fundi cancelled');
              if (context.mounted) context.pop();
            }
          },
        ));
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: actions);
  }
}

// ─── Review card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final BookingModel booking;
  const _ReviewCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final clientId = context.read<AuthProvider>().userModel?.uid ?? '';
    if (clientId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: context
          .read<ReviewProvider>()
          .hasReviewedStream(booking.bookingId, clientId),
      initialData: false,
      builder: (context, snap) {
        if (snap.data == true) {
          return Container(
            padding:    const EdgeInsets.all(AppTheme.spaceLG),
            decoration: BoxDecoration(
              color:        AppColors.successSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border:       Border.all(
                  color: AppColors.success.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.task_alt_rounded, color: AppColors.success),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Review submitted',
                      style: AppTextStyles.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Thank you for helping other clients choose trusted fundis.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ]),
              ),
            ]),
          );
        }
        return AppButton(
          label:       'Leave a Review',
          leadingIcon: Icons.star_rounded,
          onPressed:   () =>
              context.push('/client/submit-review', extra: booking),
        );
      },
    );
  }
}

// ─── Info banner ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   message;
  const _InfoBanner(
      {required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border:       Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
              child: Text(message,
                  style:
                      AppTextStyles.caption.copyWith(color: color))),
        ]),
      );
}

// ─── Person card ──────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final String  label, name, subtitle;
  final String? imageUrl, phone;
  final bool    phoneHidden;

  const _PersonCard({
    required this.label,
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.phone,
    this.phoneHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppTheme.spaceSM),
        Row(children: [
          AppAvatar(imageUrl: imageUrl, name: name, size: 48),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name, style: AppTextStyles.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary)),
              if (phone != null || phoneHidden) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.grey500),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      phoneHidden ? '07** *** ***' : phone!,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: phoneHidden
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (phoneHidden) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline,
                        size: 12, color: AppColors.grey400),
                  ],
                ]),
              ],
            ]),
          ),
        ]),
        // NEW: contact hint only for pending (not "agree to unlock")
        if (phoneHidden) ...[
          const SizedBox(height: AppTheme.spaceMD),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
            decoration: BoxDecoration(
                color:        AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM)),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                  child: Text(
                'Contacts unlock after fundi accepts your booking.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Detail card ──────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String   title, content;
  const _DetailCard(
      {required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) => Container(
        padding:    const EdgeInsets.all(AppTheme.spaceLG),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
                child: Text(title,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.primary))),
          ]),
          const SizedBox(height: AppTheme.spaceMD),
          Text(content, style: AppTextStyles.bodyMedium),
        ]),
      );
}

// ─── Timeline ─────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final BookingModel booking;
  const _Timeline({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final events = <_TE>[
      _TE('Booking Created', b.createdAt, true, Icons.add_circle_outline),
      _TE('Fundi Accepted', b.acceptedAt,
          b.isAccepted || b.isInProgress || b.isAwaitingConfirmation ||
              b.isCompletionDisputed || b.isCompleted || b.isAgreementConfirmed,
          Icons.check_circle_outline),
      _TE('Job Started', b.startedAt,
          b.isInProgress || b.isAwaitingConfirmation ||
              b.isCompletionDisputed || b.isCompleted,
          Icons.construction_rounded),
      _TE('Fundi Marked Done', b.completionRequestedAt ?? b.completedByFundiAt,
          b.isAwaitingConfirmation || b.isCompletionDisputed || b.isCompleted,
          Icons.task_alt_rounded),
      if (b.isCompleted)
        _TE('Client Confirmed', b.clientConfirmedCompletionAt ?? b.completedAt,
            true, Icons.verified_rounded),
      if (b.isCompletionDisputed)
        _TE('Dispute Submitted', b.disputedAt ?? b.updatedAt,
            true, Icons.warning_amber_rounded),
      if (b.isRejected)
        _TE('Booking Rejected', b.rejectedAt ?? b.updatedAt,
            true, Icons.block_rounded),
      if (b.isCancelled)
        _TE('Booking Cancelled', b.cancelledAt ?? b.updatedAt,
            true, Icons.cancel_outlined),
    ];

    return Container(
      padding:    const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border:       Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Timeline',
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
        const SizedBox(height: AppTheme.spaceMD),
        ...events.asMap().entries.map(
              (e) => _TEItem(event: e.value, isLast: e.key == events.length - 1),
            ),
      ]),
    );
  }
}

class _TE {
  final String    label;
  final DateTime? date;
  final bool      done;
  final IconData  icon;
  const _TE(this.label, this.date, this.done, this.icon);
}

class _TEItem extends StatelessWidget {
  final _TE  event;
  final bool isLast;
  const _TEItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: event.done ? AppColors.success : AppColors.grey200,
                  shape: BoxShape.circle),
              child: Icon(event.icon,
                  size: 14,
                  color: event.done ? AppColors.white : AppColors.grey400),
            ),
            if (!isLast)
              Container(
                  width: 2, height: 32,
                  color: event.done
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.grey200),
          ]),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(event.label,
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: event.done
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: event.done
                            ? AppColors.textPrimary
                            : AppColors.textHint)),
                if (event.date != null)
                  Text(AppUtils.formatDateTime(event.date!),
                      style: AppTextStyles.caption),
                const SizedBox(height: AppTheme.spaceLG),
              ]),
            ),
          ),
        ],
      );
}
