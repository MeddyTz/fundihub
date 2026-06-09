import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class FundiUploadReelScreen extends StatefulWidget {
  const FundiUploadReelScreen({super.key});

  @override
  State<FundiUploadReelScreen> createState() => _State();
}

class _State extends State<FundiUploadReelScreen>
    with SingleTickerProviderStateMixin {
  final _captionCtrl = TextEditingController();
  // category is auto-read from user profile (no manual selection needed)

  VideoPlayerController? _previewCtrl;
  bool _previewPlaying = false;

  late final AnimationController _successAnim;
  String? _lastShownError; // prevents double-snackbar

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReelProvider>().resetUpload();
    });
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _previewCtrl?.dispose();
    _successAnim.dispose();
    super.dispose();
  }

  // ── Pick ──────────────────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    final prov = context.read<ReelProvider>();
    final ok   = await prov.pickVideo();
    if (!mounted) return;

    if (ok && prov.pickedVideoFile != null) {
      await _initPreview(prov.pickedVideoFile!);
    } else if (!ok && prov.uploadError != null) {
      _snack(prov.uploadError!, isError: true);
    }
  }

  Future<void> _initPreview(File file) async {
    await _previewCtrl?.dispose();
    _previewCtrl = null;
    setState(() => _previewPlaying = false);

    try {
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize().timeout(const Duration(seconds: 8));
      if (mounted) {
        ctrl.setLooping(true);
        setState(() => _previewCtrl = ctrl);
      } else {
        await ctrl.dispose();
      }
    } catch (_) {
      // Preview unavailable — upload can still proceed
    }
  }

  void _togglePreview() {
    final ctrl = _previewCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (_previewPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    setState(() => _previewPlaying = !_previewPlaying);
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final prov = context.read<ReelProvider>();

    if (prov.pickedVideoFile == null) {
      _snack('Please select a video first.', isError: true);
      return;
    }
    final caption = _captionCtrl.text.trim();
    if (caption.length < 10) {
      _snack('Caption must be at least 10 characters.', isError: true);
      return;
    }

    _previewCtrl?.pause();
    setState(() => _previewPlaying = false);

    final user = context.read<AuthProvider>().userModel;
    if (user == null) {
      _snack('Not signed in. Please sign in again.', isError: true);
      return;
    }

    // Upload via Cloudinary (unsigned preset fundihub_reels on da4vbrmuv)
    final reelId = await prov.uploadReelViaCloudinary(
      fundiId:           user.uid,
      fundiName:         user.fullName,
      fundiProfileImage: user.profileImageUrl ?? '',
      category:          user.category.isNotEmpty ? user.category : 'General',
      caption:           caption,
      location: [user.district, user.region]
          .where((s) => s.trim().isNotEmpty)
          .join(', '),
      rating:   0.0,
      jobsDone: 0,
    );

    if (!mounted) return;

    if (reelId != null) {
      _showSuccess();
    }
    // Error is shown in didUpdateWidget via listener
  }

  // ── Cancel ────────────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    final prov = context.read<ReelProvider>();
    if (!prov.isUploading) {
      prov.resetUpload();
      return true;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('Cancel Upload?'),
        content: const Text('Your video upload is in progress. Cancel it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Uploading'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Upload'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await prov.cancelUpload();
      return true;
    }
    return false;
  }

  void _showSuccess() {
    _successAnim.forward(from: 0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(anim: _successAnim),
    ).then((_) {
      if (mounted) {
        context.read<ReelProvider>().resetUpload();
        context.pop();
      }
    });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior:  SnackBarBehavior.floating,
        margin:    const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:     RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<ReelProvider>();
    final l10n  = AppL10n.of(context);
    final state = prov.uploadState;

    // Show errors reactively — only once per message
    if (state == ReelUploadState.error &&
        prov.uploadError != null &&
        prov.uploadError != 'Upload cancelled.' &&
        prov.uploadError != _lastShownError) {
      _lastShownError = prov.uploadError;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _snack(prov.uploadError!, isError: true));
    }

    final isActiveUpload = prov.isUploading;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            l10n.sw ? 'Shiriki Kazi Yako' : 'Share Your Work',
            style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.white, fontWeight: FontWeight.w700),
          ),
          backgroundColor:  AppColors.primary,
          foregroundColor:  AppColors.white,
          elevation:        0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _onWillPop() && mounted) context.pop();
            },
          ),
        ),
        body: isActiveUpload
            ? _UploadProgressView(
                state:    state,
                progress: prov.uploadProgress,
                onCancel: () async {
                  await prov.cancelUpload();
                  if (mounted) context.pop();
                },
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Video picker / preview ───────────────────
                    _VideoSection(
                      hasVideo:    prov.pickedVideoFile != null,
                      videoFile:   prov.pickedVideoFile,
                      previewCtrl: _previewCtrl,
                      duration:    prov.videoDuration,
                      isPlaying:   _previewPlaying,
                      isPreparing: state == ReelUploadState.preparing,
                      onPick:      _pickVideo,
                      onToggle:    _togglePreview,
                      onClear: () {
                        _previewCtrl?.dispose();
                        _previewCtrl = null;
                        setState(() => _previewPlaying = false);
                        prov.clearPickedVideo();
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Category (auto from profile) ─────────────
                    const _Label('Service Category'),
                    const SizedBox(height: 8),
                    Builder(builder: (ctx) {
                      final u = ctx.watch<AuthProvider>().userModel;
                      final cat = (u?.category.isNotEmpty == true)
                          ? u!.category
                          : 'Not set';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color:        AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.work_outline_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(cat,
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text('auto',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary)),
                        ]),
                      );
                    }),
                    const SizedBox(height: 4),
                    Text(
                      'Category is taken from your profile',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // ── Caption ──────────────────────────────────
                    const _Label('Caption *'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _captionCtrl,
                      label: l10n.sw
                          ? 'Elezea kazi yako (min 10 herufi)'
                          : 'Describe your work (min 10 characters)',
                      hint: l10n.sw
                          ? 'mf. Nilibadilisha bomba kubwa...'
                          : 'e.g. I fixed a burst pipe and retiled...',
                      maxLines:   4,
                      prefixIcon: Icons.edit_note_rounded,
                    ),
                    const SizedBox(height: 14),

                    _TipsCard(l10n: l10n),
                    const SizedBox(height: 28),

                    // ── Submit ───────────────────────────────────
                    AppButton(
                      label: l10n.sw ? 'Pakia Video' : 'Upload Video',
                      onPressed: prov.pickedVideoFile != null
                          ? _submit
                          : null,
                      leadingIcon: Icons.cloud_upload_rounded,
                      type: prov.pickedVideoFile != null
                          ? AppButtonType.primary
                          : AppButtonType.secondary,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        l10n.sw
                            ? '* Reels zinakaguliwa kabla ya kuchapishwa'
                            : '* Reels are reviewed before going live',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Upload Progress ───────────────────────────────────────────────────────────

class _UploadProgressView extends StatelessWidget {
  final ReelUploadState state;
  final double          progress;
  final VoidCallback    onCancel;

  const _UploadProgressView({
    required this.state,
    required this.progress,
    required this.onCancel,
  });

  String get _step {
    switch (state) {
      case ReelUploadState.preparing: return 'Preparing…';
      case ReelUploadState.uploading: return 'Uploading Video…';
      case ReelUploadState.saving:    return 'Saving Reel…';
      default:                        return 'Please wait…';
    }
  }

  String get _sub {
    switch (state) {
      case ReelUploadState.uploading:
        return '${(progress * 100).toInt()}%  ·  do not close the app';
      case ReelUploadState.saving:
        return 'Almost done — saving your reel details';
      default:
        return 'Getting ready to upload';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIndeterminate =
        state == ReelUploadState.saving || state == ReelUploadState.preparing;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon box
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                    color:      AppColors.primary.withOpacity(0.35),
                    blurRadius: 22, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.cloud_upload_rounded,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 28),

            Text(_step,
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),

            Text(_sub,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value:      isIndeterminate ? null : progress,
                minHeight:  10,
                backgroundColor: AppColors.primarySurface,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),

            if (state == ReelUploadState.uploading && progress > 0) ...[
              const SizedBox(height: 10),
              Text('${(progress * 100).toInt()}%',
                  style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],

            const SizedBox(height: 36),

            // ── Step indicator ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepDot(label: 'Prepare', done: state != ReelUploadState.preparing,
                    active: state == ReelUploadState.preparing),
                _StepLine(active: state == ReelUploadState.uploading ||
                    state == ReelUploadState.saving),
                _StepDot(label: 'Upload', done: state == ReelUploadState.saving,
                    active: state == ReelUploadState.uploading),
                _StepLine(active: state == ReelUploadState.saving),
                _StepDot(label: 'Save',   done: false,
                    active: state == ReelUploadState.saving),
              ],
            ),

            const SizedBox(height: 32),

            // Cancel
            OutlinedButton.icon(
              onPressed: onCancel,
              icon:  const Icon(Icons.close_rounded, size: 16),
              label: const Text('Cancel Upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool   done;
  final bool   active;
  const _StepDot({required this.label, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = done   ? AppColors.success :
                  active ? AppColors.primary  : AppColors.grey300;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 14, height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 10)
              : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            fontSize: 9, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32, height: 2,
      color: active ? AppColors.primary : AppColors.grey200,
    ),
  );
}

// ── Video Section ─────────────────────────────────────────────────────────────

class _VideoSection extends StatelessWidget {
  final bool                    hasVideo;
  final File?                   videoFile;
  final VideoPlayerController?  previewCtrl;
  final Duration?               duration;
  final bool                    isPlaying;
  final bool                    isPreparing;
  final VoidCallback            onPick;
  final VoidCallback            onToggle;
  final VoidCallback            onClear;

  const _VideoSection({
    required this.hasVideo,
    required this.videoFile,
    required this.previewCtrl,
    required this.duration,
    required this.isPlaying,
    required this.isPreparing,
    required this.onPick,
    required this.onToggle,
    required this.onClear,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (isPreparing) {
      return _placeholder(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const AppWrenchLoader(),
          const SizedBox(height: 14),
          Text('Reading video…',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }

    if (!hasVideo) {
      return GestureDetector(
        onTap: onPick,
        child: _placeholder(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.video_call_rounded,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 14),
            Text('Tap to pick a video',
                style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('MP4 · MOV · Max 50 MB · Max 60 sec',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    // Preview
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      child: Stack(children: [
        SizedBox(
          height: 260, width: double.infinity,
          child: previewCtrl != null && previewCtrl!.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:  previewCtrl!.value.size.width,
                    height: previewCtrl!.value.size.height,
                    child:  VideoPlayer(previewCtrl!),
                  ),
                )
              : Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(Icons.videocam_rounded,
                        color: Colors.white30, size: 52),
                  ),
                ),
        ),
        // Play/pause overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              color: isPlaying ? Colors.transparent : Colors.black45,
              child: isPlaying
                  ? const SizedBox()
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:  Colors.white.withOpacity(0.25),
                          shape:  BoxShape.circle,
                          border: Border.all(color: Colors.white60, width: 2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
            ),
          ),
        ),
        // Duration
        if (duration != null)
          Positioned(bottom: 10, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.timer_rounded, color: Colors.white70, size: 12),
                const SizedBox(width: 4),
                Text(_fmt(duration!),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        // Buttons
        Positioned(top: 10, right: 10,
          child: Row(children: [
            _OBtn(icon: Icons.swap_horiz_rounded, label: 'Change', onTap: onPick),
            const SizedBox(width: 6),
            _OBtn(icon: Icons.delete_rounded,     label: 'Remove',
                color: Colors.redAccent, onTap: onClear),
          ]),
        ),
      ]),
    );
  }

  Widget _placeholder({required Widget child}) => Container(
        height: 220, width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
        ),
        child: child,
      );
}

class _OBtn extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap; final Color color;
  const _OBtn({required this.icon, required this.label,
      required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── Success Dialog ────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final AnimationController anim;
  const _SuccessDialog({required this.anim});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: anim,
        builder: (_, child) => Transform.scale(
            scale: Curves.elasticOut.transform(anim.value), child: child),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXXL)),
          contentPadding: const EdgeInsets.all(32),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Reel Submitted! 🎉',
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Your video is under review.\nIt will go live once approved.',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD)),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700));
}

class _TipsCard extends StatelessWidget {
  final AppL10n l10n;
  const _TipsCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final tips = l10n.sw
        ? ['Onyesha kazi nzuri uliyoifanya', 'Video fupi (15–60 sec) hufanya vizuri', 'Hakikisha mwanga ni mzuri']
        : ['Show your best completed work', 'Short clips (15–60 sec) perform best', 'Good lighting matters'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_rounded, color: Color(0xFFF57F17), size: 16),
          const SizedBox(width: 6),
          Text(l10n.sw ? 'Vidokezo' : 'Tips for a great reel',
              style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ...tips.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
                Expanded(child: Text(t, style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))),
              ]),
            )),
      ]),
    );
  }
}
