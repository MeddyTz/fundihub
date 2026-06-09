import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../common/app_loader.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/message_model.dart';
import '../common/app_avatar.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onDelete;
  final List<MessageModel> imageMessages;
  final int initialImageIndex;
  final String? otherName;
  final String? otherImageUrl;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
    this.imageMessages = const [],
    this.initialImageIndex = 0,
    this.otherName,
    this.otherImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? AppTheme.space4XL : AppTheme.spaceLG,
          right: isMe ? AppTheme.spaceLG : AppTheme.space4XL,
          top: AppTheme.spaceXS,
          bottom: AppTheme.spaceXS,
        ),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for incoming messages
            if (!isMe) ...[
              AppAvatar(
                imageUrl: otherImageUrl,
                name: otherName ?? '',
                size: 30,
              ),
              const SizedBox(width: 6),
            ],

            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name for incoming
                  if (!isMe &&
                      (otherName ?? '').trim().isNotEmpty &&
                      (otherName ?? '').trim() != 'User')
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        otherName!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  _MessageContent(
                    message: message,
                    isMe: isMe,
                    imageMessages: imageMessages,
                    initialImageIndex: initialImageIndex,
                  ),

                  const SizedBox(height: 3),

                  _MessageFooter(message: message, isMe: isMe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    if (message.isDeleted) return;
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
            if (message.isText && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: AppColors.primary),
                title: const Text('Copy Message'),
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: message.text ?? ''));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            if (isMe && !message.isDeleted && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: const Text('Delete Message',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
            const SizedBox(height: AppTheme.spaceLG),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message content dispatcher
// ─────────────────────────────────────────────────────────────────────────────

class _MessageContent extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final List<MessageModel> imageMessages;
  final int initialImageIndex;

  const _MessageContent({
    required this.message,
    required this.isMe,
    this.imageMessages = const [],
    this.initialImageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _TextBubble(
          text: '🚫 This message was deleted',
          isMe: isMe,
          deleted: true);
    }
    if (message.isLocation) {
      return _LocationBubble(
        lat: message.locationLat ?? 0,
        lng: message.locationLng ?? 0,
        label: message.locationLabel ?? 'Shared location',
        isMe: isMe,
      );
    }
    if (message.isImage) {
      return _ImageBubble(
        imageUrl: message.imageUrl ?? '',
        isMe: isMe,
        imageMessages: imageMessages,
        initialImageIndex: initialImageIndex,
      );
    }
    if (message.isVoice) {
      return _VoiceBubble(
        voiceUrl: message.voiceUrl ?? '',
        durationMs: message.voiceDurationMs,
        isMe: isMe,
      );
    }
    return _TextBubble(text: message.text ?? '', isMe: isMe);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text bubble
// ─────────────────────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool deleted;

  const _TextBubble(
      {required this.text, required this.isMe, this.deleted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM + 2),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.chatBubbleSent
            : AppColors.chatBubbleReceived,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppTheme.radiusLG),
          topRight: const Radius.circular(AppTheme.radiusLG),
          bottomLeft: isMe
              ? const Radius.circular(AppTheme.radiusLG)
              : const Radius.circular(4),
          bottomRight: isMe
              ? const Radius.circular(4)
              : const Radius.circular(AppTheme.radiusLG),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(isMe ? 0.12 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: AppTextStyles.chatMessage.copyWith(
          color: isMe ? AppColors.white : AppColors.textPrimary,
          fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image bubble
// ─────────────────────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isMe;
  final List<MessageModel> imageMessages;
  final int initialImageIndex;

  const _ImageBubble({
    required this.imageUrl,
    required this.isMe,
    this.imageMessages = const [],
    this.initialImageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _MediaFallback(
          isMe: isMe,
          icon: Icons.broken_image_outlined,
          title: 'Photo unavailable');
    }

    return GestureDetector(
      onTap: () {
        final gallery = imageMessages
            .where((m) => (m.imageUrl ?? '').trim().isNotEmpty)
            .toList();
        final fallback = gallery.isEmpty
            ? [
                MessageModel(
                  messageId: imageUrl,
                  chatId: '',
                  senderId: '',
                  senderName: '',
                  type: 'image',
                  imageUrl: imageUrl,
                  isSeen: true,
                  isDelivered: true,
                  isDeleted: false,
                  createdAt: DateTime.now(),
                )
              ]
            : gallery;
        final safeIndex =
            initialImageIndex >= 0 && initialImageIndex < fallback.length
                ? initialImageIndex
                : 0;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
                images: fallback, initialIndex: safeIndex),
          ),
        );
      },
      child: Hero(
        tag: imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70,
                maxHeight: 260),
            color: AppColors.grey200,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                        width: 220,
                        height: 180,
                        child: Center(
                            child: AppLoader(size: 22)));
                  },
                  errorBuilder: (_, __, ___) => _MediaFallback(
                      isMe: isMe,
                      icon: Icons.broken_image_outlined,
                      title: 'Failed to load photo'),
                ),
                if (imageMessages.length > 1)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.collections_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${initialImageIndex + 1}/${imageMessages.length}',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice bubble
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceBubble extends StatefulWidget {
  final String voiceUrl;
  final int? durationMs;
  final bool isMe;

  const _VoiceBubble(
      {required this.voiceUrl,
      required this.durationMs,
      required this.isMe});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.voiceUrl.isEmpty) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.voiceUrl));
      if (mounted) setState(() => _playing = true);
    }
  }

  String _durationLabel(int? ms) {
    if (ms == null || ms <= 0) return '0:00';
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMe ? AppColors.white : AppColors.textPrimary;
    final muted = widget.isMe
        ? AppColors.white.withOpacity(0.75)
        : AppColors.textSecondary;

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: widget.isMe
            ? AppColors.chatBubbleSent
            : AppColors.chatBubbleReceived,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [
          BoxShadow(
            color: AppColors.black
                .withOpacity(widget.isMe ? 0.12 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(999),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: widget.isMe
                  ? AppColors.white.withOpacity(0.18)
                  : AppColors.primarySurface,
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: fg,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Icon(Icons.graphic_eq_rounded, color: muted),
          const SizedBox(width: AppTheme.spaceSM),
          Text(
            _durationLabel(widget.durationMs),
            style: AppTextStyles.caption.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location bubble
// ─────────────────────────────────────────────────────────────────────────────

class _LocationBubble extends StatelessWidget {
  final double lat, lng;
  final String label;
  final bool isMe;

  const _LocationBubble(
      {required this.lat,
      required this.lng,
      required this.label,
      required this.isMe});

  Future<void> _openMaps(BuildContext context) async {
    if (lat == 0 && lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates unavailable')),
      );
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openMaps(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.chatBubbleSent
              : AppColors.chatBubbleReceived,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: isMe
                ? AppColors.white.withOpacity(0.2)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  AppColors.black.withOpacity(isMe ? 0.12 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLG),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                      child: CustomPaint(
                          painter: _MapPreviewPainter())),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.error, size: 38),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceSM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isMe
                                ? AppColors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to open in Maps',
                    style: AppTextStyles.caption.copyWith(
                      color: isMe
                          ? AppColors.white.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = AppColors.white.withOpacity(0.9)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = AppColors.grey300.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * .25),
        Offset(size.width, size.height * .10), thin);
    canvas.drawLine(Offset(size.width * .12, 0),
        Offset(size.width * .86, size.height), thin);
    canvas.drawLine(Offset(0, size.height * .68),
        Offset(size.width, size.height * .48), road);
    canvas.drawLine(Offset(size.width * .28, 0),
        Offset(size.width * .48, size.height), road);
    canvas.drawLine(Offset(0, size.height * .92),
        Offset(size.width * .70, 0), thin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Media fallback
// ─────────────────────────────────────────────────────────────────────────────

class _MediaFallback extends StatelessWidget {
  final bool isMe;
  final IconData icon;
  final String title;

  const _MediaFallback(
      {required this.isMe, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.70),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.chatBubbleSent
            : AppColors.chatBubbleReceived,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color:
                  isMe ? AppColors.white : AppColors.textSecondary),
          const SizedBox(width: AppTheme.spaceSM),
          Flexible(
            child: Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: isMe ? AppColors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message footer — time + read tick
// ─────────────────────────────────────────────────────────────────────────────

class _MessageFooter extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageFooter({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppUtils.formatTime(message.createdAt),
            style: AppTextStyles.chatTime,
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            // Single grey tick = sent (delivered but not seen)
            // Double blue tick = seen
            Icon(
              message.isSeen
                  ? Icons.done_all_rounded
                  : message.isDelivered
                      ? Icons.done_all_rounded
                      : Icons.done_rounded,
              size: 15,
              color: message.isSeen
                  ? AppColors.primary          // ✓✓ blue = seen
                  : AppColors.grey400,          // ✓✓ grey = delivered
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer
// ─────────────────────────────────────────────────────────────────────────────

class _FullScreenImageViewer extends StatefulWidget {
  final List<MessageModel> images;
  final int initialIndex;

  const _FullScreenImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          count > 1 ? '${_index + 1} of $count' : 'Photo',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: count,
        onPageChanged: (v) => setState(() => _index = v),
        itemBuilder: (_, index) {
          final msg = widget.images[index];
          final url = msg.imageUrl ?? '';
          return _ZoomableImage(
            imageUrl: url,
            heroTag: url,
            footer: msg.senderName.trim().isEmpty
                ? null
                : '${msg.senderName} • ${AppUtils.formatTime(msg.createdAt)}',
          );
        },
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String? footer;

  const _ZoomableImage(
      {required this.imageUrl, required this.heroTag, this.footer});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _ctrl = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      if (_zoomed) {
        _ctrl.value = Matrix4.identity();
        _zoomed = false;
      } else {
        _ctrl.value = Matrix4.identity()..scale(2.2);
        _zoomed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onDoubleTap: _toggleZoom,
            child: Hero(
              tag: widget.heroTag,
              child: InteractiveViewer(
                transformationController: _ctrl,
                minScale: 0.8,
                maxScale: 5,
                onInteractionEnd: (_) =>
                    _zoomed = _ctrl.value.getMaxScaleOnAxis() > 1.05,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                        child: AppLoader(size: 18, color: Colors.white));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white, size: 52),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.footer != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Text(widget.footer!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
      ],
    );
  }
}
