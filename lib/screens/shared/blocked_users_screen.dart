import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/block_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final blockProv = context.watch<BlockProvider>();
    final myId = auth.userModel?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: blockProv.blockedUsers.isEmpty
          ? const AppEmptyState(
              icon: Icons.block_rounded,
              title: 'No Blocked Users',
              subtitle: 'Users you block will appear here.',
              iconColor: AppColors.grey400,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spaceXXL),
              itemCount: blockProv.blockedUsers.length,
              itemBuilder: (_, i) {
                final block = blockProv.blockedUsers[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      AppAvatar(name: block.blockedName, size: 44),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(block.blockedName,
                                style: AppTextStyles.titleSmall),
                            Text(
                              'Blocked ${AppUtils.formatRelativeTime(block.createdAt)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirm = await AppUtils.showConfirmDialog(
                            context,
                            title: 'Unblock User?',
                            message:
                                'Unblock ${block.blockedName}? They will be able to message you again.',
                            confirmText: 'Unblock',
                          );
                          if (confirm == true) {
                            await blockProv.unblockUser(
                              blockerId: myId,
                              blockedId: block.blockedId,
                            );
                          }
                        },
                        child: const Text('Unblock'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}