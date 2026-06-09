import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Reports'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreConstants.reports)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoaderCenter();
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No Pending Reports',
              subtitle: 'All reports have been reviewed.',
              iconColor: AppColors.success,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spaceXXL),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final report = ReportModel.fromMap(
                  docs[i].data() as Map<String, dynamic>);
              return _ReportCard(report: report, docId: docs[i].id);
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final String docId;
  const _ReportCard({required this.report, required this.docId});

  Future<void> _updateStatus(BuildContext context, String status) async {
    final adminId =
        context.read<AuthProvider>().userModel?.uid ?? '';
    await FirebaseFirestore.instance
        .collection(FirestoreConstants.reports)
        .doc(docId)
        .update({
      'status': status,
      'reviewedBy': adminId,
      'reviewedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _suspendUser(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection(FirestoreConstants.users)
        .doc(report.reportedUserId)
        .update({
      'accountStatus': 'suspended',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    await _updateStatus(context, 'action_taken');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reporter info
          Row(
            children: [
              AppAvatar(name: report.reporterName, size: 36),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reported by: ${report.reporterName}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    Text(AppUtils.formatDateTime(report.createdAt),
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text('Pending',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          const Divider(),
          const SizedBox(height: AppTheme.spaceMD),
          // Reported user
          Row(
            children: [
              const Icon(Icons.person_off_rounded,
                  size: 16, color: AppColors.error),
              const SizedBox(width: 6),
              Text('Against: ',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              Text(report.reportedUserName,
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // Reason
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSM),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: ${report.reason}',
                    style: AppTextStyles.titleSmall),
                const SizedBox(height: 4),
                Text(report.details, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateStatus(context, 'dismissed'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.grey600,
                      side: const BorderSide(color: AppColors.grey300)),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final ok = await AppUtils.showConfirmDialog(
                      context,
                      title: 'Suspend User?',
                      message:
                          'Suspend ${report.reportedUserName}? They will be blocked from using the app.',
                      confirmText: 'Suspend',
                      isDanger: true,
                    );
                    if (ok == true && context.mounted) {
                      await _suspendUser(context);
                      if (context.mounted) {
                        AppUtils.showSnackBar(
                            context, 'User suspended.');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error),
                  child: const Text('Suspend User'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}