import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/lang_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/fundi_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/cards/fundi_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

class NearbyFundisScreen extends StatefulWidget {
  const NearbyFundisScreen({super.key});

  @override
  State<NearbyFundisScreen> createState() => _NearbyFundisScreenState();
}

class _NearbyFundisScreenState extends State<NearbyFundisScreen> {
  bool _loading = true;
  String? _error;
  double? _myLat;
  double? _myLng;
  List<_NearbyFundi> _nearby = [];

  static const String _notificationsRoute = '/notifications';

  @override
  void initState() {
    super.initState();
    _detectAndLoad();
  }

  Future<void> _detectAndLoad() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context.read<LocationService>().detectLocation();
      _myLat = result.latitude;
      _myLng = result.longitude;
    } on LocationError catch (e) {
      final user = context.read<AuthProvider>().userModel;

      if (user?.latitude != null && user?.longitude != null) {
        _myLat = user!.latitude;
        _myLng = user.longitude;
      } else {
        _myLat = null;
        _myLng = null;
        _error = '${LocationService.errorMessage(e)}\n\nShowing all fundis instead.';
      }
    } catch (_) {
      final user = context.read<AuthProvider>().userModel;
      _myLat = user?.latitude;
      _myLng = user?.longitude;
    }

    await _loadFundis();
  }

  Future<void> _loadFundis() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'fundi')
          .where('isProfileComplete', isEqualTo: true)
          .where('accountStatus', isEqualTo: 'active')
          .limit(100)
          .get();

      final fundis = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        data['uid'] ??= d.id;
        return FundiModel.fromMap(data);
      }).toList();

      final items = fundis.map((f) {
        final hasFundiGps = f.latitude != null && f.longitude != null;
        final hasMyGps = _myLat != null && _myLng != null;

        if (hasMyGps && hasFundiGps) {
          return _NearbyFundi(
            fundi: f,
            distKm: _haversineKm(
              _myLat!,
              _myLng!,
              f.latitude!,
              f.longitude!,
            ),
          );
        }

        return _NearbyFundi(
          fundi: f,
          distKm: double.infinity,
        );
      }).toList();

      items.sort(_compareNearby);

      if (!mounted) return;

      setState(() {
        _nearby = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = AppL10n.of(context).failedToLoad;
        _loading = false;
      });
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;


  double _trustScore(FundiModel f) {
    double score = 0;

    if (f.isPromoted) score += 10000;
    if (f.isPremium) score += 5000;

    score += f.jobsDone * 80;
    score += f.rating * 120;
    score += f.reviewCount * 12;

    if (f.isProfileComplete) score += 100;

    return score;
  }

  int _compareNearby(_NearbyFundi a, _NearbyFundi b) {
    final aHasDistance = a.distKm != double.infinity;
    final bHasDistance = b.distKm != double.infinity;

    if (aHasDistance && bHasDistance) {
      final distanceGap = (a.distKm - b.distKm).abs();

      // Distance remains the main nearby rule. If fundis are close to each other,
      // trust signals decide who appears first.
      if (distanceGap > 2) {
        return a.distKm.compareTo(b.distKm);
      }

      final trustCompare = _trustScore(b.fundi).compareTo(_trustScore(a.fundi));
      if (trustCompare != 0) return trustCompare;
      return a.distKm.compareTo(b.distKm);
    }

    if (aHasDistance && !bHasDistance) return -1;
    if (!aHasDistance && bHasDistance) return 1;

    final trustCompare = _trustScore(b.fundi).compareTo(_trustScore(a.fundi));
    if (trustCompare != 0) return trustCompare;
    return a.fundi.fullName.toLowerCase().compareTo(b.fundi.fullName.toLowerCase());
  }


  String _distLabel(double km) {
    if (km == double.infinity) return '';
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  Stream<int> _unreadNotificationsStream() {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    return context.read<NotificationService>().notificationStream(uid);
  }

  void _openNotifications() {
    try {
      context.push(_notificationsRoute);
    } catch (_) {
      try {
        context.push('/client/notifications');
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications route is not connected yet.'),
          ),
        );
      }
    }
  }

  Widget _notificationBell() {
    return StreamBuilder<int>(
      stream: _unreadNotificationsStream(),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: _openNotifications,
            ),
            if (count > 0)
              Positioned(
                right: 7,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final fundisWithGps = _nearby.where((f) => f.distKm != double.infinity).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Builder(builder:(ctx)=>Text(AppL10n.of(ctx).fundisNearMe)),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          _notificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _detectAndLoad,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLoader(),
                  const SizedBox(height: 16),
                  Text(l10n.findingFundis),
                ],
              ),
            )
          : Column(
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.all(AppTheme.spaceXXL),
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_off_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_myLat != null && _myLng != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXXL,
                      vertical: AppTheme.spaceSM,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$fundisWithGps fundis with GPS — sorted by distance + trust',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _nearby.isEmpty
                      ? AppEmptyState(
                          icon: Icons.location_searching,
                          title: l10n.noFundisNearby,
                          subtitle: l10n.noFundisNearbySubtitle,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.spaceXXL,
                            AppTheme.spaceMD,
                            AppTheme.spaceXXL,
                            AppTheme.space3XL,
                          ),
                          itemCount: _nearby.length,
                          itemBuilder: (_, i) {
                            final item = _nearby[i];
                            final distanceLabel = _distLabel(item.distKm);

                            return FundiCard(
                              fundi: item.fundi,
                              distanceLabel:
                                  distanceLabel.isEmpty ? null : distanceLabel,
                              onTap: () => context.push(
                                '/client/fundi-details',
                                extra: item.fundi,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _NearbyFundi {
  final FundiModel fundi;
  final double distKm;

  const _NearbyFundi({
    required this.fundi,
    required this.distKm,
  });
}