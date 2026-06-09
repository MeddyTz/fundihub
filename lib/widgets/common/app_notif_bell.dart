import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/notification_provider.dart';

/// AppNotifBell — reads the shared [NotificationProvider] singleton.
///
/// The provider now runs TWO Firestore queries:
///   Q1: userId == uid  AND isRead == false
///   Q2: userId == uid  AND read   == false
/// Both results are unioned by notifId, so the counter is always accurate
/// whether the doc has `isRead`, `read`, or both fields.
///
/// The bell updates in real-time because both stream subscriptions call
/// notifyListeners() whenever Firestore emits a new snapshot.
class AppNotifBell extends StatelessWidget {
  final double badgeRight;
  final double badgeTop;

  const AppNotifBell({
    super.key,
    this.badgeRight = 7,
    this.badgeTop   = 7,
  });

  @override
  Widget build(BuildContext context) {
    final count = context.watch<NotificationProvider>().totalUnread;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon:     const Icon(Icons.notifications_outlined, color: AppColors.white),
          onPressed: () => context.push('/notifications'),
          tooltip:  'Notifications',
        ),
        if (count > 0)
          Positioned(
            right: badgeRight,
            top:   badgeTop,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border:       Border.all(color: AppColors.white, width: 1.2),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color:      AppColors.white,
                    fontSize:   10,
                    fontWeight: FontWeight.w800,
                    height:     1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
