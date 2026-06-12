import 'dart:io';

import '../../services/cloudinary_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/location_picker.dart';
import '../../widgets/common/app_loader.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _State();
}

class _State extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _isUploading = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel!;
    _nameCtrl.text = user.fullName;
    _phoneCtrl.text = user.phone;
    _regionCtrl.text = user.region;
    _districtCtrl.text = user.district;
    _areaCtrl.text = user.area;
    _bioCtrl.text = user.bio;

  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _regionCtrl.dispose();
    _districtCtrl.dispose();
    _areaCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ── Profile image ─────────────────────────────────────────────────────────

  Future<void> _pickImage({bool camera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;
    final file = File(picked.path);
    if (!AppUtils.isImageSizeValid(await file.length())) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Image too large. Max 5 MB.',
            isError: true);
      }
      return;
    }
    setState(() => _imageFile = file);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spaceSM),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(AppL10n.of(context).takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickImage(camera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(AppL10n.of(context).chooseGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            const SizedBox(height: AppTheme.spaceLG),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_imageFile == null) return null;
    try {
      final result = await CloudinaryService().uploadImage(
        file:   _imageFile!,
        folder: 'profiles/$uid',
      );
      return result.secureUrl;
    } on CloudinaryException catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Image upload failed: ${e.message}',
            isError: true);
      }
      return null;
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Image upload failed.',
            isError: true);
      }
      return null;
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final region = _regionCtrl.text.trim();
    final district = _districtCtrl.text.trim();

    if (region.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter your region', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.userModel!;

    setState(() => _isUploading = true);
    try {
      // Upload profile image
      final imageUrl =
          _imageFile != null ? await _uploadProfileImage(user.uid) : null;


      final updates = <String, dynamic>{
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'region': region,
        'district': district,
        'area': _areaCtrl.text.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        if (imageUrl != null) 'profileImageUrl': imageUrl,
        if (user.isFundi && _bioCtrl.text.trim().isNotEmpty)
          'bio': _bioCtrl.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);
      await auth.refreshUser();

      if (mounted) {
        AppUtils.showSnackBar(context, 'Profile updated successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Failed to update profile',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel!;
    final isFundi = user.isFundi;

    return AppLoadingOverlay(
      isLoading: _isUploading,
      message: 'Saving...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Builder(builder:(c)=>Text(AppL10n.of(c).editProfile)),
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceXXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Profile Photo ─────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceSheet,
                        child: _imageFile != null
                            ? ClipOval(
                                child: Image.file(_imageFile!,
                                    width: 100, height: 100, fit: BoxFit.cover),
                              )
                            : AppAvatar(
                                imageUrl: user.profileImageUrl,
                                name: user.fullName,
                                size: 100,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 16, color: AppColors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Tap photo to change',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXXL),

                // ── Personal Info ─────────────────────────────────
                AppTextField(
                  controller: _nameCtrl,
                  label: AppL10n.of(context).fullName,
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: Validators.validateFullName,
                ),
                const SizedBox(height: AppTheme.spaceXL),
                AppTextField(
                  controller: _phoneCtrl,
                  label: AppL10n.of(context).phoneNumber,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.validatePhone,
                ),

                if (isFundi) ...[
                  const SizedBox(height: AppTheme.spaceXL),
                  AppTextField(
                    controller: _bioCtrl,
                    label: AppL10n.of(context).bio,
                    hint: 'Example: I am an experienced electrician with 5 years of home and office repair experience...',
                    prefixIcon: Icons.description_outlined,
                    maxLines: 4,
                  ),
                ],
                const SizedBox(height: AppTheme.spaceXXL),

                // ── Location ──────────────────────────────────────
                _SectionLabel(
                    label: AppL10n.of(context).location, icon: Icons.location_on_rounded),
                const SizedBox(height: AppTheme.spaceMD),

                LocationPicker(
                  regionCtrl: _regionCtrl,
                  districtCtrl: _districtCtrl,
                  areaCtrl: _areaCtrl,
                ),

                const SizedBox(height: AppTheme.space3XL),
                AppButton(
                  label: AppL10n.of(context).saveChanges,
                  onPressed: _save,
                  isLoading: _isUploading,
                  leadingIcon: Icons.check_rounded,
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

// ─── Section label widget ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String   label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

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
