import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_notif_bell.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primary,
          automaticallyImplyLeading: false,
          actions: [
            if ((user?.uid ?? '').isNotEmpty) const AppNotifBell(),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.white),
              onPressed: () => auth.logout(),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.heroGradient),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppTheme.spaceXL),
                    GestureDetector(
                      onTap: () => context.push('/edit-profile'),
                      child: Stack(children: [
                        AppAvatar(
                            imageUrl: user?.profileImageUrl,
                            name: user?.fullName ?? '',
                            size: 76,
                            backgroundColor: AppColors.white.withOpacity(0.2)),
                        Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.edit_rounded,
                                    size: 12, color: AppColors.primary))),
                      ]),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    Text(user?.fullName ?? '',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.white)),
                    const SizedBox(height: 4),
                    const AppBadge(type: BadgeType.verified, customLabel: 'Client'),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceXXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Info cards ─────────────────────────────────────────
                _Info(icon: Icons.email_outlined, label: 'Email',
                    value: user?.email ?? ''),
                const SizedBox(height: AppTheme.spaceSM),
                _Info(icon: Icons.phone_outlined, label: 'Phone',
                    value: user?.phone.isNotEmpty == true
                        ? user!.phone
                        : 'Not set'),
                const SizedBox(height: AppTheme.spaceSM),
                _Info(icon: Icons.location_on_outlined, label: 'Location',
                    value: user != null
                        ? '${user.district}, ${user.region}'
                        : 'Not set'),

                const SizedBox(height: AppTheme.spaceXXL),

                // ── Account Settings ───────────────────────────────────
                Text(l10n.accountSettings, style: AppTextStyles.titleLarge),
                const SizedBox(height: AppTheme.spaceMD),

                _Tile(
                  icon: Icons.edit_outlined,
                  title: l10n.editProfile,
                  sub: 'Update your info and photo',
                  onTap: () => context.push('/edit-profile'),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _Tile(
                  icon:  Icons.bookmark_rounded,
                  title: 'Saved Reels',
                  sub:   'Reels you bookmarked for later',
                  onTap: () => context.push('/saved-reels'),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _Tile(
                  icon: Icons.notifications_outlined,
                  title: l10n.notifications,
                  sub: 'View your notifications',
                  onTap: () => context.push('/notifications'),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _Tile(
                  icon: Icons.block_rounded,
                  title: l10n.blockedUsers,
                  sub: 'Manage blocked users',
                  onTap: () => context.push('/blocked-users'),
                ),

                const SizedBox(height: AppTheme.spaceSM),

                // ── Language switcher ──────────────────────────────────
                _LanguageTile(),

                const SizedBox(height: AppTheme.spaceSM),

                // ── Help & Support ─────────────────────────────────────
                _Tile(
                  icon: Icons.help_outline,
                  title: l10n.helpSupport,
                  sub: 'WhatsApp, Email & FAQ',
                  onTap: () => _showHelp(context, l10n),
                ),

                const SizedBox(height: AppTheme.spaceSM),

                // ── Share App ──────────────────────────────────────────
                _Tile(
                  icon: Icons.share_rounded,
                  title: l10n.shareApp,
                  sub: 'Invite friends to FundiHub',
                  onTap: () => Share.share(l10n.shareMessage),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _Tile(
                  icon: Icons.star_rounded,
                  title: 'Rate Us',
                  sub: 'Enjoy FundiHub? Leave us a review',
                  onTap: () => _rateUs(context),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _Tile(
                  icon: Icons.info_outline_rounded,
                  title: 'About FundiHub',
                  sub: 'Version, team & mission',
                  onTap: () => _showAbout(context),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _Tile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  sub: 'How we handle your data',
                  onTap: () => _openPrivacy(context),
                ),

                const SizedBox(height: AppTheme.space3XL),

                AppButton(
                  label: l10n.signOut,
                  type: AppButtonType.outline,
                  leadingIcon: Icons.logout,
                  onPressed: () => auth.logout(),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                AppButton(
                  label: 'Delete Account',
                  type: AppButtonType.outline,
                  leadingIcon: Icons.delete_forever_rounded,
                  onPressed: () =>
                      _confirmDeleteAccount(context, auth, l10n),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 96),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _rateUs(BuildContext context) async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/details'
        '?id=com.fundihub.app');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('About FundiHub'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FundiHub connects clients with skilled '
                'professionals across Tanzania.'),
            SizedBox(height: 10),
            Text('Version: 1.0.0'),
            Text('Built by TzTech'),
            Text('Contact: tztech26@gmail.com'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final uri = Uri.parse('https://fundihub.co.tz/privacy');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('fundihub.co.tz/privacy')));
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, AuthProvider auth, AppL10n l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('Delete Account?'),
        content: const Text(
            'Your account will be permanently deactivated.\n\n'
            'All your bookings and data will be hidden.\n\n'
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete My Account')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await auth.deleteAccount();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error));
    }
  }

  void _showHelp(BuildContext context, AppL10n l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HelpSheet(l10n: l10n),
    );
  }
}

// ── Help sheet ─────────────────────────────────────────────────────────────

class _HelpSheet extends StatelessWidget {
  final AppL10n l10n;
  const _HelpSheet({required this.l10n});

  Future<void> _whatsapp(BuildContext ctx) async {
    final uri = Uri.parse(
        'https://wa.me/255754967156?text=${Uri.encodeComponent('Hello FundiHub Support, I need help with the app.')}');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('WhatsApp: +255754967156'),
        duration: Duration(seconds: 4),
      ));
    }
  }

  Future<void> _email(BuildContext ctx) async {
    const address = 'tztech26@gmail.com';
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      queryParameters: {
        'subject': 'FundiHub Support',
        'body': 'Hi FundiHub Team,\n\nI need help with:\n\n',
      },
    );
    // Attempt to open the mail app directly.
    // canLaunchUrl is unreliable for mailto on Android — try first.
    bool opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && ctx.mounted) {
      // Fallback: copy the email address and inform the user.
      await Clipboard.setData(const ClipboardData(text: address));
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text(
              'Email copied: tztech26@gmail.com\n'
              'Paste it in your mail app.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      [l10n.faqQ1, l10n.faqA1],
      [l10n.faqQ2, l10n.faqA2],
      [l10n.faqQ3, l10n.faqA3],
      [l10n.faqQ4, l10n.faqA4],
      [l10n.faqQ5, l10n.faqA5],
      [l10n.faqQ6, l10n.faqA6],
      [l10n.faqQ7, l10n.faqA7],
    ];

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceXXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.helpSupport,
                    style: AppTextStyles.headlineSmall
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppTheme.spaceLG),
                Row(children: [
                  Expanded(
                    child: _ContactButton(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _whatsapp(context),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: _ContactButton(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      color: AppColors.primary,
                      onTap: () => _email(context),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXXL),
            child: Row(children: [
              const Icon(Icons.quiz_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(l10n.faq,
                  style: AppTextStyles.titleMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXXL),
              itemCount: faqs.length,
              itemBuilder: (_, i) => _FaqTile(
                  question: faqs[i][0], answer: faqs[i][1]),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXXL),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                    color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _FaqTile extends StatefulWidget {
  final String question, answer;
  const _FaqTile({required this.question, required this.answer});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: AppColors.border)),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _open = v),
          trailing: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: AppColors.primary),
          title: Text(widget.question,
              style: AppTextStyles.titleSmall
                  .copyWith(fontWeight: FontWeight.w600)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLG, 0, AppTheme.spaceLG, AppTheme.spaceLG),
              child: Text(widget.answer,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

// ── Language tile ──────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangProvider>();
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.language_rounded, color: AppColors.primary),
        const SizedBox(width: AppTheme.spaceMD),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.language, style: AppTextStyles.titleSmall),
              Text(lang.isSwahili ? '🇹🇿 Kiswahili' : '🇬🇧 English',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ]),
        ),
        Row(children: [
          _LangBtn(
            flag: '🇬🇧',
            label: 'EN',
            selected: !lang.isSwahili,
            onTap: () => lang.setEnglish(),
          ),
          const SizedBox(width: 8),
          _LangBtn(
            flag: '🇹🇿',
            label: 'SW',
            selected: lang.isSwahili,
            onTap: () => lang.setSwahili(),
          ),
        ]),
      ]),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String flag, label;
  final bool selected;
  final VoidCallback onTap;
  const _LangBtn(
      {required this.flag,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.grey100,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Text('$flag $label',
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              )),
        ),
      );
}

// ── Shared tile widgets ───────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Info({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppTheme.spaceMD),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.bodyMedium),
        ])
      ]));
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback onTap;
  const _Tile(
      {required this.icon,
      required this.title,
      this.sub,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  if (sub != null)
                    Text(sub!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                ])),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.grey400),
          ])));
}
