import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/location_picker.dart';

class FundiProfileCompletionScreen extends StatefulWidget {
  const FundiProfileCompletionScreen({super.key});

  @override
  State<FundiProfileCompletionScreen> createState() =>
      _FundiProfileCompletionScreenState();
}

class _FundiProfileCompletionScreenState
    extends State<FundiProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();

  String? _category;
  String? _experience;
  double? _lat;
  double? _lng;
  String _addr = '';

  final List<String> _skills = [];
  final List<String> _expOptions = const [
    'Less than 1 year',
    '1 - 2 years',
    '3 - 5 years',
    '5 - 10 years',
    'More than 10 years',
  ];

  bool get _isOther => _category == AppConstants.categoryOthers;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otherCtrl.dispose();
    _bioCtrl.dispose();
    _regionCtrl.dispose();
    _districtCtrl.dispose();
    _areaCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  void _addSkill() {
    final skill = _skillCtrl.text.trim();
    if (skill.isEmpty) return;
    final alreadyExists =
        _skills.any((s) => s.toLowerCase() == skill.toLowerCase());
    if (alreadyExists) {
      AppUtils.showSnackBar(context, 'Skill already added');
      return;
    }
    setState(() {
      _skills.add(skill);
      _skillCtrl.clear();
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_category == null) {
      AppUtils.showSnackBar(context, 'Please select your service category',
          isError: true);
      return;
    }
    if (_isOther && _otherCtrl.text.trim().isEmpty) {
      AppUtils.showSnackBar(context, 'Please describe your service',
          isError: true);
      return;
    }
    if (_experience == null) {
      AppUtils.showSnackBar(context, 'Please select your experience',
          isError: true);
      return;
    }

    final region = _regionCtrl.text.trim();
    final district = _districtCtrl.text.trim();

    if (region.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter your region', isError: true);
      return;
    }
    if (district.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter your district',
          isError: true);
      return;
    }
    if (_skills.isEmpty) {
      AppUtils.showSnackBar(context, 'Please add at least one skill',
          isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.completeFundiProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      category: _category!,
      otherCategoryName: _isOther ? _otherCtrl.text.trim() : null,
      skills: _skills,
      experience: _experience!,
      bio: _bioCtrl.text.trim(),
      region: region,
      district: district,
      area: _areaCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      detectedAddress: _addr,
    );

    // If !mounted the router already navigated away — that is success.
    // NEVER show an error snackbar in that case.
    if (!mounted) return;
    if (!ok) {
      AppUtils.showSnackBar(
        context,
        auth.errorMessage ?? 'Failed to save. Please try again.',
        isError: true,
      );
    } else {
      // Clear stale reels cache so the new fundi's profile starts empty.
      context.read<ReelProvider>().clearFundiReels();
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

                  AuthHeader(
                    title: 'Fundi Profile',
                    subtitle:
                        'Complete your profile to start receiving bookings',
                  ),
                  const SizedBox(height: AppTheme.space3XL),

                  // ── Personal Info ───────────────────────────────
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. John Makamba',
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

                  // ── Service Category ────────────────────────────
                  _Label(label: 'Service Category', icon: Icons.work_outline),
                  const SizedBox(height: AppTheme.spaceMD),
                  AppDropdown<String>(
                    value: _category,
                    items: AppConstants.serviceCategories,
                    label: 'Service Category',
                    hint: 'What service do you provide?',
                    itemLabel: (c) => c,
                    validator: (v) =>
                        v == null ? 'Please select a category' : null,
                    onChanged: (v) => setState(() => _category = v),
                  ),

                  if (_isOther) ...[
                    const SizedBox(height: AppTheme.spaceXL),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceMD),
                      decoration: BoxDecoration(
                        color: AppColors.warningSurface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Your service will be reviewed by admin',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceSM),
                          AppTextField(
                            controller: _otherCtrl,
                            label: 'Describe Your Service',
                            hint: 'e.g. Pool cleaner, drone operator...',
                            prefixIcon: Icons.edit_outlined,
                            validator: _isOther
                                ? (v) => Validators.validateRequired(v,
                                    fieldName: 'Service description')
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.spaceXL),
                  AppDropdown<String>(
                    value: _experience,
                    items: _expOptions,
                    label: 'Years of Experience',
                    hint: 'How long have you been working?',
                    itemLabel: (e) => e,
                    validator: (v) =>
                        v == null ? 'Please select your experience' : null,
                    onChanged: (v) => setState(() => _experience = v),
                  ),
                  const SizedBox(height: AppTheme.space3XL),

                  // ── Skills ──────────────────────────────────────
                  _Label(label: 'Your Skills', icon: Icons.star_outline),
                  const SizedBox(height: AppTheme.spaceSM),
                  Text('Add specific skills that describe what you do',
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppTheme.spaceMD),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _skillCtrl,
                          label: 'Add Skill',
                          hint: 'e.g. Bathroom fitting',
                          prefixIcon: Icons.add_circle_outline,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addSkill(),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      ElevatedButton(
                        onPressed: _addSkill,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(52, 52),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spaceMD),
                    Wrap(
                      spacing: AppTheme.spaceSM,
                      runSpacing: AppTheme.spaceSM,
                      children: _skills
                          .map((skill) => Chip(
                                label: Text(skill),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () =>
                                    setState(() => _skills.remove(skill)),
                                backgroundColor: AppColors.primarySurface,
                                labelStyle: AppTextStyles.labelMedium
                                    .copyWith(color: AppColors.primary),
                                side: const BorderSide(
                                    color: AppColors.primary, width: 0.5),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: AppTheme.space3XL),

                  // ── Bio ─────────────────────────────────────────
                  _Label(
                      label: 'About You',
                      icon: Icons.description_outlined),
                  const SizedBox(height: AppTheme.spaceMD),
                  AppTextField(
                    controller: _bioCtrl,
                    label: 'Professional Bio',
                    hint: 'Describe your services and specializations...',
                    maxLines: 4,
                    validator: (v) =>
                        Validators.validateMinLength(v, 30, fieldName: 'Bio'),
                  ),
                  const SizedBox(height: AppTheme.space3XL),

                  // ── Location — no dropdown ──────────────────────
                  _Label(
                      label: 'Your Location',
                      icon: Icons.location_on_outlined),
                  const SizedBox(height: AppTheme.spaceMD),

                  LocationPicker(
                    regionCtrl: _regionCtrl,
                    districtCtrl: _districtCtrl,
                    areaCtrl: _areaCtrl,
                    onLatChanged: (v) => _lat = v,
                    onLngChanged: (v) => _lng = v,
                    onAddressChanged: (v) => _addr = v,
                  ),

                  const SizedBox(height: AppTheme.space3XL),

                  AppButton(
                    label: 'Complete Registration',
                    onPressed: _save,
                    isLoading: auth.isLoading,
                    leadingIcon: Icons.check_circle_outline,
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

// ─── Header ───────────────────────────────────────────────────────────────────

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
            decoration:
                BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
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

class _Label extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Label({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppTheme.spaceSM),
          Text(label,
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.primary)),
        ],
      );
}
