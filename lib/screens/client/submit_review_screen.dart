import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/review_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';

class SubmitReviewScreen extends StatefulWidget {
  final BookingModel booking;
  const SubmitReviewScreen({super.key, required this.booking});

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  double _rating = 5.0;
  bool _alreadyReviewed = false;
  bool _checking = true;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAlreadyReviewed());
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAlreadyReviewed() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    final reviewed = await context
        .read<ReviewProvider>()
        .hasReviewed(widget.booking.bookingId, user.uid);

    if (!mounted) return;
    setState(() {
      _alreadyReviewed = reviewed;
      _checking = false;
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    if (widget.booking.clientId != user.uid) {
      AppUtils.showSnackBar(
        context,
        AppL10n.of(context).onlyClientCanReview,
        isError: true,
      );
      return;
    }

    if (!widget.booking.isCompleted) {
      AppUtils.showSnackBar(
        context,
        AppL10n.of(context).reviewAfterComplete,
        isError: true,
      );
      return;
    }

    // FIX: comment is optional — only rating is required
    final comment = _commentCtrl.text.trim();

    final provider = context.read<ReviewProvider>();
    final ok = await provider.submitReview(
      bookingId: widget.booking.bookingId,
      client: user,
      fundiId: widget.booking.fundiId,
      rating: _rating,
      comment: comment,
    );

    if (!mounted) return;
    if (ok) {
      setState(() => _alreadyReviewed = true);
      AppUtils.showSnackBar(context, AppL10n.of(context).reviewSubmittedThanks);
      context.pop();
    } else {
      AppUtils.showSnackBar(
        context,
        provider.errorMessage ?? 'Failed to submit review',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewProvider>();

    return AppLoadingOverlay(
      isLoading: provider.isSubmitting || _checking,
      message: _checking ? AppL10n.of(context).checkingReview : AppL10n.of(context).submittingReview,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Builder(builder:(ctx)=>Text(AppL10n.of(ctx).rateYourExperience)),
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
              _FundiReviewHeader(booking: widget.booking),
              const SizedBox(height: AppTheme.spaceXXL),
              if (_alreadyReviewed)
                _AlreadyReviewedCard(onDone: () => context.pop())
              else if (!widget.booking.isCompleted)
                const _LockedReviewCard()
              else ...[
                Text(
                  AppL10n.of(context).yourRating,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceMD),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 42,
                          color: filled ? AppColors.premium : AppColors.grey300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  _ratingLabel,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.premium,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceXXL),
                AppTextField(
                  controller: _commentCtrl,
                  label: AppL10n.of(context).yourReview + ' (optional)',
                  hint: AppL10n.of(context).reviewHint,
                  maxLines: 5,
                ),
                const SizedBox(height: AppTheme.spaceLG),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    'Your review helps other clients choose trusted fundis and helps good fundis grow on FundiHub.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space3XL),
                AppButton(
                  label: 'Submit Review',
                  leadingIcon: Icons.star_rounded,
                  onPressed: _submit,
                  isLoading: provider.isSubmitting,
                ),
              ],
              const SizedBox(height: AppTheme.space3XL),
            ],
          ),
        ),
      ),
    );
  }

  String get _ratingLabel {
    switch (_rating.toInt()) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
}

class _FundiReviewHeader extends StatelessWidget {
  final BookingModel booking;
  const _FundiReviewHeader({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: booking.fundiProfileImage,
            name: booking.fundiName,
            size: 56,
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.fundiName, style: AppTextStyles.titleLarge),
                const SizedBox(height: 2),
                Text(
                  booking.fundiCategory,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.serviceDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyReviewedCard extends StatelessWidget {
  final VoidCallback onDone;
  const _AlreadyReviewedCard({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXL),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.success.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 44),
          const SizedBox(height: AppTheme.spaceMD),
          Text('Review already submitted', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'Thank you. Each completed booking can only be reviewed once.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppTheme.spaceLG),
          AppButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

class _LockedReviewCard extends StatelessWidget {
  const _LockedReviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXL),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.warning, size: 44),
          const SizedBox(height: AppTheme.spaceMD),
          Text('Review locked', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'You can review the fundi only after the job has been completed.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
