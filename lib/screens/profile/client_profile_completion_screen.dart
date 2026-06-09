import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/location_picker.dart';

class ClientProfileCompletionScreen extends StatefulWidget {
  const ClientProfileCompletionScreen({super.key});

  @override
  State<ClientProfileCompletionScreen> createState() => _State();
}

class _State extends State<ClientProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  double? _lat, _lng;
  String _addr = '';
  String _locMode = 'manual';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _regionCtrl.dispose();
    _districtCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final region = _regionCtrl.text.trim();
    final district = _districtCtrl.text.trim();

    if (region.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter your region', isError: true);
      return;
    }
    if (district.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter your district', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.completeClientProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      region: region,
      district: district,
      area: _areaCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      detectedAddress: _addr,
      savedLocationPreference: _locMode,
    );

    if (!mounted) return;
    if (!ok) {
      AppUtils.showSnackBar(
        context,
        auth.errorMessage ?? 'Failed to save profile',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AppLoadingOverlay(
      isLoading: auth.isLoading,
      message: 'Saving profile...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXXL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppTheme.space3XL),

                  // Header
                  _Header(
                    title: 'Complete Your Profile',
                    subtitle:
                        'Tell us about yourself so fundis can help you better',
                    icon: Icons.person_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppTheme.space3XL),

                  // Personal info
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. Amina Hassan',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: Validators.validateFullName,
                  ),
                  const SizedBox(height: AppTheme.spaceXL),
                  AppTextField(
                    controller: _phoneCtrl,
                    label: 'Phone Number',
                    hint: '07XXXXXXXX',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: Validators.validatePhone,
                  ),
                  const SizedBox(height: AppTheme.space3XL),

                  // Location section
                  _SectionLabel(
                    label: 'Your Location',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: AppTheme.spaceMD),

                  LocationPicker(
                    regionCtrl: _regionCtrl,
                    districtCtrl: _districtCtrl,
                    areaCtrl: _areaCtrl,
                    onLatChanged: (v) {
                      _lat = v;
                      if (v != null) _locMode = 'gps';
                    },
                    onLngChanged: (v) => _lng = v,
                    onAddressChanged: (v) => _addr = v,
                  ),

                  const SizedBox(height: AppTheme.space3XL),

                  AppButton(
                    label: 'Save Profile',
                    onPressed: _save,
                    isLoading: auth.isLoading,
                    trailingIcon: Icons.check_rounded,
                  ),
                  const SizedBox(height: AppTheme.space3XL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: AppTheme.spaceLG),
          Text(title,
              style: AppTextStyles.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spaceSM),
          Text(subtitle,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppTheme.spaceSM),
          Text(label,
              style:
                  AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
        ],
      );
}
