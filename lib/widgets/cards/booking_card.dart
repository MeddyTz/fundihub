import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/booking_model.dart';
import '../../providers/lang_provider.dart';
import '../common/app_avatar.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isClient;
  final VoidCallback onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.isClient,
    required this.onTap,
  });

  Color _statusColor() => AppUtils.getBookingStatusColor(booking.status);

  IconData _statusIcon() {
    switch (booking.status.toLowerCase()) {
      case 'pending':             return Icons.hourglass_top_rounded;
      case 'accepted':            return Icons.check_circle_outline_rounded;
      case 'agreement_confirmed': return Icons.handshake_rounded;
      case 'in_progress':         return Icons.build_rounded;
      case 'completed':           return Icons.task_alt_rounded;
      case 'rejected':            return Icons.cancel_outlined;
      case 'cancelled':           return Icons.remove_circle_outline_rounded;
      default:                    return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final statusColor = _statusColor();
    final name  = isClient ? booking.fundiName  : booking.clientName;
    final image = isClient ? booking.fundiProfileImage : booking.clientProfileImage;
    final cat   = booking.fundiCategory;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status bar ───────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLG, vertical: 9),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.09)),
                child: Row(children: [
                  Icon(_statusIcon(), size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    AppUtils.getBookingStatusDisplay(booking.status),
                    style: AppTextStyles.labelMedium.copyWith(
                        color: statusColor, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time_rounded,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text(AppUtils.formatRelativeTime(booking.createdAt),
                      style: AppTextStyles.caption),
                ]),
              ),

              // ── Main content ─────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Person row
                    Row(children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.15),
                              width: 2),
                        ),
                        child: AppAvatar(
                            imageUrl: image, name: name, size: 46),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull)),
                              child: Text(cat,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: AppColors.grey100,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: AppColors.grey600),
                      ),
                    ]),

                    const SizedBox(height: AppTheme.spaceMD),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppTheme.spaceMD),

                    // Service description
                    _InfoRow(
                      color: AppColors.primarySurface,
                      icon: Icons.description_outlined,
                      iconColor: AppColors.primary,
                      text: booking.serviceDescription,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),

                    // Location
                    _InfoRow(
                      color: AppColors.errorSurface,
                      icon: Icons.location_on_outlined,
                      iconColor: AppColors.error,
                      text:
                          '${booking.locationArea.isNotEmpty ? "${booking.locationArea}, " : ""}${booking.locationDistrict}, ${booking.locationRegion}',
                      maxLines: 1,
                    ),

                    // Agreement pills
                    if (booking.isAccepted ||
                        booking.isAgreementConfirmed) ...[
                      const SizedBox(height: AppTheme.spaceMD),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMD,
                            vertical: AppTheme.spaceSM),
                        decoration: BoxDecoration(
                            color: AppColors.grey50,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD),
                            border: Border.all(color: AppColors.border)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Pill(l10n.clientLabel, booking.clientAgreed),
                            Container(
                                width: 1,
                                height: 20,
                                color: AppColors.border),
                            _Pill(l10n.fundiLabel, booking.fundiAgreed),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final Color color, iconColor;
  final IconData icon;
  final String text;
  final int maxLines;

  const _InfoRow({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: color,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSM)),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool agreed;
  const _Pill(this.label, this.agreed);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        agreed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        size: 15,
        color: agreed ? AppColors.success : AppColors.grey400,
      ),
      const SizedBox(width: 5),
      Text(
        '$label ${agreed ? (l10n.sw ? "Imekubaliwa" : "Agreed") : (l10n.sw ? "Inasubiri" : "Pending")}',
        style: AppTextStyles.caption.copyWith(
          color: agreed ? AppColors.success : AppColors.textHint,
          fontWeight: agreed ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ]);
  }
}
