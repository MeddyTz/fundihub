import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/fundi_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/location_picker.dart';

class CreateBookingScreen extends StatefulWidget {
  final FundiModel fundi;
  const CreateBookingScreen({super.key, required this.fundi});
  @override
  State<CreateBookingScreen> createState() => _State();
}

class _State extends State<CreateBookingScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _descCtrl       = TextEditingController();
  final _regionCtrl     = TextEditingController();
  final _districtCtrl   = TextEditingController();
  final _areaCtrl       = TextEditingController();
  final _detailsCtrl    = TextEditingController();

  double? _locationLat, _locationLng;
  String  _locationDetectedAddress = '';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _regionCtrl.text   = user.region;
      _districtCtrl.text = user.district;
      _areaCtrl.text     = user.area;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _regionCtrl.dispose();
    _districtCtrl.dispose();
    _areaCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final region   = _regionCtrl.text.trim();
    final district = _districtCtrl.text.trim();

    if (region.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter region', isError: true);
      return;
    }
    if (district.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter district', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final prov = context.read<BookingProvider>();

    final id = await prov.createBooking(
      client:                   auth.userModel!,
      fundi:                    widget.fundi,
      serviceDescription:       _descCtrl.text.trim(),
      locationRegion:           region,
      locationDistrict:         district,
      locationArea:             _areaCtrl.text.trim(),
      locationDetails:          _detailsCtrl.text.trim().isNotEmpty
                                    ? _detailsCtrl.text.trim()
                                    : null,
      locationLat:              _locationLat,
      locationLng:              _locationLng,
      locationDetectedAddress:  _locationDetectedAddress,
    );

    if (!mounted) return;

    if (id != null) {
      AppUtils.showSnackBar(context, 'Booking request sent!');
      context.pop();
    } else {
      AppUtils.showSnackBar(
        context,
        prov.errorMessage ?? 'Failed to send booking',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BookingProvider>();
    final l10n = AppL10n.of(context);

    return AppLoadingOverlay(
      isLoading: prov.isSubmitting,
      message:   'Sending booking...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title:           Text(l10n.bookAFundi),
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon:      const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceXXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FundiCard(fundi: widget.fundi),
                const SizedBox(height: AppTheme.spaceXXL),

                // ── Job description ──────────────────────────────────────
                _Hdr(icon: Icons.description_outlined, title: l10n.jobDetails),
                const SizedBox(height: AppTheme.spaceMD),
                AppTextField(
                  controller: _descCtrl,
                  label:      l10n.describeJob,
                  hint:       'e.g. Fix leaking pipe in bathroom, replace kitchen tap...',
                  maxLines:   4,
                  prefixIcon: Icons.edit_outlined,
                  // ── FIX: Only validate non-empty — no word count minimum ──
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please describe the job';
                    }
                    return null; // any non-empty text is valid
                  },
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // ── Agreed price (optional) ──────────────────────────────

                // ── Location ─────────────────────────────────────────────
                _Hdr(
                  icon:  Icons.location_on_outlined,
                  title: l10n.jobLocationLabel,
                ),
                const SizedBox(height: AppTheme.spaceMD),
                LocationPicker(
                  regionCtrl:    _regionCtrl,
                  districtCtrl:  _districtCtrl,
                  areaCtrl:      _areaCtrl,
                  onLatChanged:  (v) => _locationLat = v,
                  onLngChanged:  (v) => _locationLng = v,
                  onAddressChanged: (v) {
                    _locationDetectedAddress = v;
                    if (_detailsCtrl.text.trim().isEmpty) {
                      _detailsCtrl.text = v;
                    }
                  },
                ),
                const SizedBox(height: AppTheme.spaceXL),
                AppTextField(
                  controller: _detailsCtrl,
                  label:      l10n.additionalDetails,
                  hint:       'e.g. Near the blue gate, second floor...',
                  prefixIcon: Icons.info_outline,
                  maxLines:   2,
                ),
                const SizedBox(height: AppTheme.spaceXXL),

                // ── How it works banner ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color:        AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border:       Border.all(
                        color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: AppTheme.spaceSM),
                        Text(l10n.howBookingWorks,
                            style: AppTextStyles.titleSmall
                                .copyWith(color: AppColors.primary)),
                      ]),
                      const SizedBox(height: AppTheme.spaceSM),
                      ...[
                        '1. Fundi receives and accepts or rejects your request',
                        '2. Both agree to job terms in chat',
                        '3. Contact unlocked after mutual agreement',
                        '4. Fundi marks job complete when done',
                      ].map((s) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.spaceXS),
                            child: Text(s,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary
                                        .withOpacity(0.8))),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space3XL),

                AppButton(
                  label:       l10n.sendBookingRequest,
                  leadingIcon: Icons.send_rounded,
                  onPressed:   _submit,
                  isLoading:   prov.isSubmitting,
                ),
                const SizedBox(height: AppTheme.space3XL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fundi card ────────────────────────────────────────────────────────────────

class _FundiCard extends StatelessWidget {
  final FundiModel fundi;
  const _FundiCard({required this.fundi});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border:       Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color:      AppColors.black.withOpacity(0.04),
              blurRadius: 10,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          AppAvatar(
            imageUrl: fundi.profileImageUrl,
            name:     fundi.fullName,
            size:     56,
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fundi.fullName, style: AppTextStyles.titleLarge),
                const SizedBox(height: 2),
                Text(fundi.displayCategory,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.grey500),
                  const SizedBox(width: 4),
                  Text('${fundi.district}, ${fundi.region}',
                      style: AppTextStyles.caption),
                ]),
              ],
            ),
          ),
          // Verification badge (no premium/free label in growth mode)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSM, vertical: 4),
            decoration: BoxDecoration(
              color:        AppColors.successSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text('✓ Verified',
                style: AppTextStyles.caption.copyWith(
                  color:      AppColors.success,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ]),
      );
}

// ── Section header ────────────────────────────────────────────────────────────

class _Hdr extends StatelessWidget {
  final IconData icon;
  final String   title;
  const _Hdr({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppTheme.spaceSM),
        Text(title,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.primary)),
      ]);
}
