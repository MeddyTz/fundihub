import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/fundi_model.dart';
import '../common/app_avatar.dart';
import '../common/app_badge.dart';
import '../common/app_rating_bar.dart';

// ── Distance helper ───────────────────────────────────────────────────────────
// Uses Haversine formula. Returns null if either coordinate is missing.
String? _calcDistance(
  double? clientLat,
  double? clientLng,
  double? fundiLat,
  double? fundiLng,
) {
  if (clientLat == null ||
      clientLng == null ||
      fundiLat == null ||
      fundiLng == null) return null;

  const r = 6371000.0; // earth radius metres
  final dLat = _rad(fundiLat - clientLat);
  final dLng = _rad(fundiLng - clientLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(clientLat)) *
          math.cos(_rad(fundiLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final metres = r * c;

  if (metres < 1000) {
    return '${metres.round()} m away';
  } else {
    final km = metres / 1000;
    return km < 10
        ? '${km.toStringAsFixed(1)} km away'
        : '${km.round()} km away';
  }
}

double _rad(double deg) => deg * math.pi / 180;

// ── FundiCard ────────────────────────────────────────────────────────────────

class FundiCard extends StatefulWidget {
  final FundiModel fundi;
  final VoidCallback onTap;
  final bool isCompact;
  /// Pass the client's lat/lng so distance is computed inline.
  /// If null the card safely falls back to location text only.
  final double? clientLat;
  final double? clientLng;
  /// Legacy: explicit label overrides computed distance when provided.
  final String? distanceLabel;

  const FundiCard({
    super.key,
    required this.fundi,
    required this.onTap,
    this.isCompact = false,
    this.clientLat,
    this.clientLng,
    this.distanceLabel,
  });

  @override
  State<FundiCard> createState() => _FundiCardState();
}

class _FundiCardState extends State<FundiCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  FundiModel get f => widget.fundi;

  String _safeLocation() {
    final d = f.district.trim();
    final r = f.region.trim();
    if (d.isNotEmpty && r.isNotEmpty) return '$d, $r';
    if (d.isNotEmpty) return d;
    if (r.isNotEmpty) return r;
    return 'Location not set';
  }

  /// Resolved distance: explicit label wins, then computed, then null.
  String? get _distance {
    if (widget.distanceLabel != null &&
        widget.distanceLabel!.trim().isNotEmpty) {
      return widget.distanceLabel;
    }
    return _calcDistance(
      widget.clientLat,
      widget.clientLng,
      f.latitude,
      f.longitude,
    );
  }

  bool get _isTopRated => f.rating >= 4.5 && f.reviewCount >= 3;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp: (_) => _press.forward(),
      onTapCancel: () => _press.forward(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _press,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            // Boosted = purple border, top-rated = gold border, default = grey
            border: f.isPromoted
                ? Border.all(color: AppColors.promoted.withOpacity(0.55), width: 1.5)
                : _isTopRated
                    ? Border.all(color: AppColors.premium.withOpacity(0.55), width: 1.5)
                    : Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: f.isPromoted
                    ? AppColors.promoted.withOpacity(0.1)
                    : _isTopRated
                        ? AppColors.premium.withOpacity(0.08)
                        : AppColors.black.withOpacity(0.05),
                blurRadius: f.isPromoted || _isTopRated ? 16 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner (boosted or top-rated) ─────────────────────────────
              if (f.isPromoted || _isTopRated)
                _Banner(isPromoted: f.isPromoted, isTopRated: _isTopRated),

              // ── Main body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: avatar + info + arrow
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with online dot placeholder
                        Stack(
                          children: [
                            AppAvatar(
                              imageUrl: f.profileImageUrl,
                              name: f.fullName,
                              size: 60,
                            ),
                            if (f.isActive)
                              Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.surface, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Name + badges + rating
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name + badges row
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      f.fullName,
                                      style: AppTextStyles.titleSmall.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (f.isPremium)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 5),
                                      child: AppBadge(type: BadgeType.premium),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Category + trusted chip row
                              Wrap(
                                spacing: 5,
                                runSpacing: 3,
                                children: [
                                  // Category
                                  _Chip(
                                    label: f.displayCategory,
                                    color: AppColors.primary,
                                    bg: AppColors.primarySurface,
                                  ),
                                  // Trusted
                                  if (f.jobsDone >= 5)
                                    _Chip(
                                      label: '✓ Trusted',
                                      color: AppColors.success,
                                      bg: AppColors.successSurface,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // Rating
                              AppRatingBar(
                                rating: f.rating,
                                reviewCount: f.reviewCount,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: AppColors.grey300),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),

                    // ── Info row: location + distance + jobs ───────────────
                    Wrap(
                      spacing: 14,
                      runSpacing: 5,
                      children: [
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: _safeLocation(),
                          color: AppColors.grey500,
                        ),
                        if (_distance != null)
                          _InfoChip(
                            icon: Icons.near_me_rounded,
                            label: _distance!,
                            color: AppColors.primary,
                            bold: true,
                          ),
                        _InfoChip(
                          icon: Icons.task_alt_rounded,
                          label:
                              '${f.jobsDone} job${f.jobsDone == 1 ? '' : 's'}',
                          color: f.jobsDone > 0
                              ? AppColors.success
                              : AppColors.grey500,
                          bold: f.jobsDone > 0,
                        ),
                      ],
                    ),

                    // ── Skill chips (max 3, overflow-safe) ─────────────────
                    if (f.skills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: f.skills.take(3).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: AppColors.border, width: 0.8),
                            ),
                            child: Text(
                              s,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
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

// ── Banner strip ─────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final bool isPromoted;
  final bool isTopRated;
  const _Banner({required this.isPromoted, required this.isTopRated});

  @override
  Widget build(BuildContext context) {
    final color = isPromoted ? AppColors.promoted : AppColors.premium;
    final icon =
        isPromoted ? Icons.rocket_launch_rounded : Icons.star_rounded;
    final label = isPromoted ? 'Featured Fundi' : 'Top Rated';
    final badge = isPromoted ? 'Boosted' : '4.5★+';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.13), color.withOpacity(0.04)],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline chip helpers ───────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool bold;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

// FundiCardShimmer lives in app_shimmer.dart — not redefined here.
