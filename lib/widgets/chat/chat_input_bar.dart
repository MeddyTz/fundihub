import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/app_loader.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String) onSendText;
  final VoidCallback onSendImage;
  final VoidCallback onSendLocation;
  final VoidCallback? onToggleVoiceRecording;
  final bool isRecordingVoice;
  final String? lockedMessage;
  final void Function()? onTyping;
  final bool isLocked;
  final bool isSending;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendLocation,
    this.onToggleVoiceRecording,
    this.isRecordingVoice = false,
    this.lockedMessage,
    this.onTyping,
    this.isLocked = false,
    this.isSending = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final hasText = _ctrl.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
      if (hasText) widget.onTyping?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSendText(text);
    _ctrl.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return _LockedBar(message: widget.lockedMessage);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceSM,
        AppTheme.spaceMD,
        AppTheme.spaceSM + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AttachButton(
            onImage: widget.onSendImage,
            onLocation: widget.onSendLocation,
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: AppTextStyles.chatMessage,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTextStyles.chatMessage.copyWith(color: AppColors.textHint),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                    vertical: AppTheme.spaceSM + 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          GestureDetector(
            onTap: widget.isSending || !_hasText ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.primary : AppColors.grey200,
                shape: BoxShape.circle,
                boxShadow: _hasText ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  )
                ] : [],
              ),
              child: widget.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: const AppLoader(size: 20, color: AppColors.white),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: AppColors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedBar extends StatelessWidget {
  final String? message;
  const _LockedBar({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spaceXXL,
        AppTheme.spaceMD,
        AppTheme.spaceXXL,
        AppTheme.spaceMD + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: AppColors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.grey500),
          const SizedBox(width: AppTheme.spaceSM),
          Flexible(
            child: Text(
              message ?? 'Chat is closed for this booking',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onLocation;

  const _AttachButton({required this.onImage, required this.onLocation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.spaceSM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.photo_outlined, color: AppColors.primary),
                ),
                title: const Text('Send Photo'),
                subtitle: const Text('Choose an image from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  onImage();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on_outlined, color: AppColors.error),
                ),
                title: const Text('Share Location'),
                subtitle: const Text('Send your current GPS location'),
                onTap: () {
                  Navigator.pop(context);
                  onLocation();
                },
              ),
              const SizedBox(height: AppTheme.spaceLG),
            ],
          ),
        ),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: AppColors.grey100, shape: BoxShape.circle),
        child: const Icon(Icons.add_rounded, size: 22, color: AppColors.grey700),
      ),
    );
  }
}
