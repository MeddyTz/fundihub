import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_loader.dart';

/// Admin screen: view and restore soft-deleted user accounts.
class AdminDeletedAccountsScreen extends StatefulWidget {
  const AdminDeletedAccountsScreen({super.key});
  @override
  State<AdminDeletedAccountsScreen> createState() =>
      _AdminDeletedAccountsScreenState();
}

class _AdminDeletedAccountsScreenState
    extends State<AdminDeletedAccountsScreen> {
  final _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _deleted = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final snap = await _db
          .collection('users')
          .where('isDeleted', isEqualTo: true)
          .orderBy('deletedAt', descending: true)
          .get();
      setState(() {
        _deleted = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['_docId'] = d.id;
          return data;
        }).toList();
      });
    } catch (_) {
      // Fallback: query by accountStatus in case isDeleted field is missing
      try {
        final snap2 = await _db
            .collection('users')
            .where('accountStatus', isEqualTo: 'deleted')
            .get();
        setState(() {
          _deleted = snap2.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['_docId'] = d.id;
            return data;
          }).toList();
        });
      } catch (e) {
        setState(() => _error = 'Failed to load deleted accounts: $e');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> user) async {
    final uid = user['_docId'] as String? ?? user['uid'] as String? ?? '';
    final name = user['fullName'] as String? ?? user['email'] as String? ?? 'this account';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Account',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to restore $name?\n\n'
          'Their account will become active again and they '
          'will be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final adminUid =
          context.read<AuthProvider>().userModel?.uid ?? 'admin';
      await _db.collection('users').doc(uid).update({
        'accountStatus': 'active',
        'isDeleted':     false,
        'isActive':      true,
        'restoredAt':    FieldValue.serverTimestamp(),
        'restoredBy':    adminUid,
        'updatedAt':     FieldValue.serverTimestamp(),
      });
      setState(() => _deleted.removeWhere((u) => u['_docId'] == uid));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name has been restored.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to restore: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _viewDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetailsSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Accounts'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
              tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const AppLoaderCenter()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry')),
                    ]),
                  ),
                )
              : _deleted.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.delete_sweep_rounded,
                            size: 64, color: AppColors.grey400),
                        const SizedBox(height: 12),
                        const Text('No deleted accounts',
                            style: TextStyle(fontSize: 16)),
                        Text('Soft-deleted users will appear here.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spaceMD),
                        itemCount: _deleted.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final u = _deleted[i];
                          return _DeletedCard(
                            user:      u,
                            onRestore: () => _restore(u),
                            onDetails: () => _viewDetails(u),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── Deleted account card ──────────────────────────────────────────────────────

class _DeletedCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRestore, onDetails;
  const _DeletedCard({
    required this.user,
    required this.onRestore,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final name   = user['fullName']  as String? ?? '—';
    final email  = user['email']     as String? ?? '—';
    final role   = user['role']      as String? ?? '—';
    final phone  = user['phone']     as String? ?? '—';
    final status = user['accountStatus'] as String? ?? 'deleted';
    final ts     = user['deletedAt'] as Timestamp?;
    final deleted = ts != null
        ? _fmt(ts.toDate())
        : '—';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: const BorderSide(color: AppColors.error, width: .5)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.error.withOpacity(.12),
              child: const Icon(Icons.person_off_rounded,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: AppTextStyles.labelLarge
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(email,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(role.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error)),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Info rows
          _Row(Icons.phone_rounded,          'Phone',   phone),
          _Row(Icons.label_rounded,          'Status',  status),
          _Row(Icons.delete_forever_rounded, 'Deleted', deleted),
          const SizedBox(height: 12),
          // Actions
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Details'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Restore'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// ── Details sheet ─────────────────────────────────────────────────────────────

class _DetailsSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  const _DetailsSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final fields = <String, String>{
      'Full Name':  user['fullName']      as String? ?? '—',
      'Email':      user['email']         as String? ?? '—',
      'Phone':      user['phone']         as String? ?? '—',
      'Role':       user['role']          as String? ?? '—',
      'Status':     user['accountStatus'] as String? ?? '—',
      'UID':        user['uid']           as String? ?? '—',
      'Region':     user['region']        as String? ?? '—',
      'District':   user['district']      as String? ?? '—',
      'Category':   user['category']      as String? ?? '—',
      'Auth Provider': user['authProvider'] as String? ?? '—',
      'Deleted At': _ts(user['deletedAt']  as Timestamp?),
      'Created At': _ts(user['createdAt']  as Timestamp?),
      'Reason':     user['deleteReason']  as String? ?? '—',
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (_, controller) => Column(children: [
        const SizedBox(height: 10),
        Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('Account Details',
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: fields.entries
                .where((e) => e.value != '—')
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(e.key,
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(e.value, style: AppTextStyles.bodyMedium),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }

  static String _ts(Timestamp? t) {
    if (t == null) return '—';
    final d = t.toDate();
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
