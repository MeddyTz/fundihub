import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';

class WorkPhotosScreen extends StatefulWidget {
  const WorkPhotosScreen({super.key});

  @override
  State<WorkPhotosScreen> createState() => _WorkPhotosScreenState();
}

class _WorkPhotosScreenState extends State<WorkPhotosScreen> {
  List<String> _existingUrls = [];
  final List<File> _newFiles = [];
  bool _loading    = true;
  bool _saving     = false;
  bool _anyChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  // ── Load existing photos from Firestore ───────────────────────────────────
  Future<void> _load() async {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (mounted) {
        final data = doc.data();
        setState(() {
          _existingUrls = data != null && data['portfolioImages'] is List
              ? List<String>.from(data['portfolioImages'] as List)
              : [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Pick new photos from gallery ──────────────────────────────────────────
  Future<void> _pickPhotos() async {
    final remaining = 12 - _newFiles.length - _existingUrls.length;
    if (remaining <= 0) {
      AppUtils.showSnackBar(context, 'Maximum 12 workdone photos allowed.');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 75,
      limit: remaining,
    );
    if (picked.isEmpty) return;
    for (final xfile in picked) {
      final file = File(xfile.path);
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          AppUtils.showSnackBar(
              context, '${xfile.name}: too large (max 5 MB). Skipped.',
              isError: true);
        }
        continue;
      }
      if (mounted) {
        setState(() {
          _newFiles.add(file);
          _anyChanges = true;
        });
      }
    }
  }

  // ── Remove an existing uploaded photo ────────────────────────────────────
  Future<void> _removeExisting(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('Remove Workdone Photo?'),
        content: const Text(
            'This photo will be removed from your Workdone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _existingUrls.remove(url);
        _anyChanges = true;
      });
    }
  }

  // ── Upload new files and save list to Firestore ───────────────────────────
  Future<void> _save() async {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      // Upload each new file to Cloudinary
      final uploaded = <String>[];
      for (final file in _newFiles) {
        try {
          final result = await CloudinaryService().uploadImage(
            file:   file,
            folder: 'portfolio/$uid',
          );
          uploaded.add(result.secureUrl);
        } catch (e) {
          debugPrint('[WorkPhotos] upload error: $e');
        }
      }

      final allUrls = [..._existingUrls, ...uploaded];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'portfolioImages': allUrls});

      if (mounted) {
        AppUtils.showSnackBar(context, 'Workdone photos saved!');
        // Return 'workPhotos' so fundi_profile_screen animates to Work Photos tab
        context.pop('workPhotos');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Failed to save workdone photos.',
            isError: true);
        setState(() => _saving = false);
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final total = _existingUrls.length + _newFiles.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation:       0,
        title: Text(
          'Workdone ($total / 12)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (total < 12)
            IconButton(
              icon:    const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Add Photos',
              onPressed: _saving ? null : _pickPhotos,
            ),
        ],
      ),
      body: _loading
          ? _buildShimmer()
          : total == 0
              ? _buildEmpty()
              : _buildGrid(total),
      bottomNavigationBar: _anyChanges || _newFiles.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: AppButton(
                  label:       'Save Workdone',
                  leadingIcon: Icons.check_rounded,
                  isLoading:   _saving,
                  onPressed:   _saving ? null : _save,
                ),
              ),
            )
          : null,
    );
  }

  // ── Loading shimmer grid ──────────────────────────────────────────────────
  Widget _buildShimmer() => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: 9,
        itemBuilder: (_, __) => AppShimmer(
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_outlined,
                    size: 52, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text('No Workdone Yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 10),
              Text(
                'Show clients your best finished work.\n'
                'Clients trust fundis with great photos.\n'
                'Add up to 12 photos.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _pickPhotos,
                icon:  const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('Add Workdone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD)),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Photo grid with delete badges ────────────────────────────────────────
  Widget _buildGrid(int total) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        // +1 for the "Add" cell (hidden when at max)
        itemCount: total < 12 ? total + 1 : total,
        itemBuilder: (context, i) {
          // "Add more" cell — always last
          if (i == total && total < 12) {
            return GestureDetector(
              onTap: _saving ? null : _pickPhotos,
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.4),
                      width: 1.5),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        size: 28, color: AppColors.primary),
                    SizedBox(height: 4),
                    Text('Add',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }

          // Existing Cloudinary photos
          if (i < _existingUrls.length) {
            final url = _existingUrls[i];
            return _PhotoTile(
              child: Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 28))),
              onDelete: _saving ? null : () => _removeExisting(url),
            );
          }

          // Newly picked (not yet uploaded) photos
          final file = _newFiles[i - _existingUrls.length];
          return _PhotoTile(
            child: Image.file(file, fit: BoxFit.cover),
            onDelete: _saving
                ? null
                : () => setState(() {
                      _newFiles.remove(file);
                      if (_newFiles.isEmpty && !_anyChanges) {
                        _anyChanges = false;
                      }
                    }),
          );
        },
      );
}

// ── Single photo cell with a delete (×) badge ────────────────────────────────

class _PhotoTile extends StatelessWidget {
  final Widget      child;
  final VoidCallback? onDelete;
  const _PhotoTile({required this.child, this.onDelete});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          child,
          if (onDelete != null)
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
            ),
        ]),
      );
}
