import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _roleFilter = 'all';
  String _categoryFilter = 'all';
  String _search = '';

  bool get _showCategoryFilter => _roleFilter == AppConstants.roleFundi;

  String _s(dynamic value, [String fallback = '']) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _categoryOf(Map<String, dynamic> data) {
    return _s(
      data['category'],
      _s(
        data['serviceCategory'],
        _s(data['jobCategory'], _s(data['profession'], 'Uncategorized')),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    final q = _search.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final role = _s(data['role']).toLowerCase();
      final category = _categoryOf(data);

      if (_roleFilter != 'all' && role != _roleFilter) return false;
      if (_showCategoryFilter &&
          _categoryFilter != 'all' &&
          category.toLowerCase() != _categoryFilter.toLowerCase()) {
        return false;
      }

      if (q.isEmpty) return true;

      final searchable = [
        doc.id,
        data['fullName'],
        data['name'],
        data['email'],
        data['phone'],
        data['region'],
        data['district'],
        data['area'],
        data['role'],
        category,
      ].map((e) => _s(e).toLowerCase()).join(' ');

      return searchable.contains(q);
    }).toList(growable: false);
  }

  Map<String, int> _fundiCategoryCounts(List<QueryDocumentSnapshot> docs) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (_s(data['role']).toLowerCase() != AppConstants.roleFundi) continue;
      final category = _categoryOf(data);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Keep filtering client-side to avoid Firestore composite-index errors
        // when combining role/category/search filters.
        stream: FirebaseFirestore.instance
            .collection(FirestoreConstants.users)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const AppLoaderCenter();
          }
          if (snap.hasError) {
            return AppEmptyState(
              icon: Icons.warning_amber_rounded,
              title: 'Could not load users',
              subtitle: snap.error.toString(),
              iconColor: AppColors.error,
            );
          }

          final allDocs = snap.data?.docs ?? const <QueryDocumentSnapshot>[];
          final docs = _filterDocs(allDocs);
          final categoryCounts = _fundiCategoryCounts(allDocs);
          final totalUsers = allDocs.length;
          final totalFundis = allDocs
              .where((d) => _s((d.data() as Map<String, dynamic>)['role']) == AppConstants.roleFundi)
              .length;
          final totalClients = allDocs
              .where((d) => _s((d.data() as Map<String, dynamic>)['role']) == AppConstants.roleClient)
              .length;

          return Column(
            children: [
              _HeaderFilters(
                roleFilter: _roleFilter,
                categoryFilter: _categoryFilter,
                search: _search,
                categoryCounts: categoryCounts,
                totalUsers: totalUsers,
                totalClients: totalClients,
                totalFundis: totalFundis,
                onRoleChanged: (value) => setState(() {
                  _roleFilter = value;
                  if (_roleFilter != AppConstants.roleFundi) _categoryFilter = 'all';
                }),
                onCategoryChanged: (value) => setState(() => _categoryFilter = value),
                onSearchChanged: (value) => setState(() => _search = value),
              ),
              Expanded(
                child: docs.isEmpty
                    ? AppEmptyState(
                        icon: Icons.people_outline,
                        title: 'No users found',
                        subtitle: _showCategoryFilter && _categoryFilter != 'all'
                            ? 'No fundis found under $_categoryFilter. Try another category.'
                            : 'Try changing the search or filters.',
                        iconColor: AppColors.grey400,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spaceXXL),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          return _UserTile(data: data, docId: docs[i].id);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderFilters extends StatelessWidget {
  final String roleFilter;
  final String categoryFilter;
  final String search;
  final Map<String, int> categoryCounts;
  final int totalUsers, totalClients, totalFundis;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;

  const _HeaderFilters({
    required this.roleFilter,
    required this.categoryFilter,
    required this.search,
    required this.categoryCounts,
    required this.totalUsers,
    required this.totalClients,
    required this.totalFundis,
    required this.onRoleChanged,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });

  bool get _showCategoryFilter => roleFilter == AppConstants.roleFundi;

  @override
  Widget build(BuildContext context) {
    final categories = categoryCounts.keys.toList()..sort();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceXXL,
        AppTheme.spaceMD,
        AppTheme.spaceXXL,
        AppTheme.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'All', value: '$totalUsers')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Clients', value: '$totalClients')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Fundis', value: '$totalFundis')),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search name, email, phone, region or category...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => onSearchChanged(''),
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.white,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Users',
                  selected: roleFilter == 'all',
                  onTap: () => onRoleChanged('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Clients',
                  selected: roleFilter == AppConstants.roleClient,
                  onTap: () => onRoleChanged(AppConstants.roleClient),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Fundis',
                  selected: roleFilter == AppConstants.roleFundi,
                  onTap: () => onRoleChanged(AppConstants.roleFundi),
                ),
              ],
            ),
          ),
          if (_showCategoryFilter) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'View fundis by category',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categories.contains(categoryFilter) ? categoryFilter : 'all',
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All fundi categories ($totalFundis)'),
                    ),
                    ...categories.map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text('$cat (${categoryCounts[cat] ?? 0})'),
                      ),
                    ),
                  ],
                  onChanged: (value) => onCategoryChanged(value ?? 'all'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white.withOpacity(0.78),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: Colors.white.withOpacity(0.45)),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? AppColors.primary : AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _UserTile({required this.data, required this.docId});

  String _s(dynamic value, [String fallback = '']) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String get _displayName => _s(data['fullName'], _s(data['name'], 'Unknown'));
  String get _role => _s(data['role']);
  String get _category => _s(data['category'], _s(data['serviceCategory'], _s(data['jobCategory'], 'Uncategorized')));

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.users)
          .doc(docId)
          .update({
        'accountStatus': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      if (context.mounted) {
        AppUtils.showSnackBar(
          context,
          status == AppConstants.statusSuspended
              ? 'Account suspended'
              : 'Account activated',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppUtils.showSnackBar(context, 'Failed to update account: $e', isError: true);
      }
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(imageUrl: data['profileImageUrl'], name: _displayName, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, style: AppTextStyles.titleMedium),
                        Text('${_role.toUpperCase()} • ${_s(data['accountStatus'], 'active')}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailRow(Icons.email_outlined, 'Email', _s(data['email'], 'Not provided')),
              _DetailRow(Icons.phone_outlined, 'Phone', _s(data['phone'], 'Not provided')),
              _DetailRow(Icons.work_outline_rounded, 'Role', _role.isEmpty ? 'Unknown' : _role),
              if (_role == AppConstants.roleFundi)
                _DetailRow(Icons.category_outlined, 'Category', _category),
              _DetailRow(Icons.location_on_outlined, 'Location',
                  [_s(data['region']), _s(data['district']), _s(data['area'])]
                      .where((e) => e.isNotEmpty)
                      .join(' • ')
                      .trim()
                      .isEmpty
                      ? 'Not provided'
                      : [_s(data['region']), _s(data['district']), _s(data['area'])]
                          .where((e) => e.isNotEmpty)
                          .join(' • ')),
              _DetailRow(Icons.star_outline_rounded, 'Plan', _s(data['plan'], _s(data['subscriptionStatus'], 'free'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSuspended = _s(data['accountStatus']) == AppConstants.statusSuspended;
    final isFundi = _role == AppConstants.roleFundi;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: isSuspended ? AppColors.error.withOpacity(0.35) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(imageUrl: data['profileImageUrl'], name: _displayName, size: 46),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_displayName, style: AppTextStyles.titleSmall)),
                    if (isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('Suspended', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isFundi
                      ? 'Fundi • $_category'
                      : '${_role.isEmpty ? 'User' : _role} • ${_s(data['region'], 'No region')}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(_s(data['email'], 'No email'), style: AppTextStyles.caption),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'details') {
                _showDetails(context);
                return;
              }
              final status = value == 'suspend'
                  ? AppConstants.statusSuspended
                  : AppConstants.statusActive;
              await _updateStatus(context, status);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'details',
                child: Row(children: [Icon(Icons.visibility_outlined), SizedBox(width: 8), Text('View details')]),
              ),
              PopupMenuItem(
                value: isSuspended ? 'activate' : 'suspend',
                child: Row(
                  children: [
                    Icon(
                      isSuspended ? Icons.check_circle_outline : Icons.block_rounded,
                      color: isSuspended ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSuspended ? 'Activate Account' : 'Suspend Account',
                      style: TextStyle(color: isSuspended ? AppColors.success : AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
