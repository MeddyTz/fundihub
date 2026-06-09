import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/category_model.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminCategoriesScreen
// Reads from: FirestoreConstants.otherCategoryRequests  (primary source)
// Fallback:   users collection where category == 'Others' (catches fundis who
//             slipped through before the request-doc was written correctly)
// ─────────────────────────────────────────────────────────────────────────────

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  String _status = 'pending';
  String _query = '';
  bool _busy = false;

  // ── Primary stream: otherCategoryRequests collection ─────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> get _requestsStream {
    // Simple single-field filter — no composite index required.
    return FirebaseFirestore.instance
        .collection(FirestoreConstants.otherCategoryRequests)
        .where('status', isEqualTo: _status)
        .snapshots();
  }

  // ── Fallback stream: users with category == 'Others' ─────────────────────
  // Some fundis may exist without a corresponding request doc (e.g. created
  // before the request-writing code was in place, or due to the auth race
  // condition where createUserDocument completed but completeFundiProfile
  // never ran a second time).  We show these as synthetic pending requests.

  Stream<QuerySnapshot<Map<String, dynamic>>> get _fundiOthersStream {
    if (_status != 'pending') {
      // Fallback only makes sense for pending; return an empty stream.
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(FirestoreConstants.users)
        .where('role', isEqualTo: AppConstants.roleFundi)
        .where('category', isEqualTo: AppConstants.categoryOthers)
        .snapshots();
  }

  // ── Approve ───────────────────────────────────────────────────────────────

  Future<void> _approve(OtherCategoryRequest req) async {
    if (_busy) return;
    setState(() => _busy = true);

    final db = FirebaseFirestore.instance;
    final categoryName = req.otherCategoryName.trim();

    if (categoryName.isEmpty) {
      AppUtils.showSnackBar(context,
          'Cannot approve: no category name provided.', isError: true);
      setState(() => _busy = false);
      return;
    }

    try {
      final categoryId = _categoryDocId(categoryName);
      final now = Timestamp.now();

      // For synthetic requests, generate a real Firestore doc ID
      final requestRef = req.isSynthetic
          ? db.collection(FirestoreConstants.otherCategoryRequests).doc()
          : db
              .collection(FirestoreConstants.otherCategoryRequests)
              .doc(req.requestId);

      await db.runTransaction((tx) async {
        final categoryRef =
            db.collection(FirestoreConstants.categories).doc(categoryId);
        final fundiRef =
            db.collection(FirestoreConstants.users).doc(req.fundiId);

        final categorySnap = await tx.get(categoryRef);

        // Create or update the category document
        if (!categorySnap.exists) {
          tx.set(categoryRef, {
            'name': categoryName,
            'iconName': 'handyman',
            'isActive': true,
            'fundiCount': 1,
            'createdAt': now,
            'updatedAt': now,
            'createdFromRequestId': requestRef.id,
          });
        } else {
          tx.update(categoryRef, {
            'isActive': true,
            'updatedAt': now,
            'fundiCount': FieldValue.increment(1),
          });
        }

        // Write the request doc (create for synthetic, update for real)
        if (req.isSynthetic) {
          tx.set(requestRef, {
            'requestId': requestRef.id,
            'fundiId': req.fundiId,
            'fundiName': req.fundiName,
            'phone': req.phone,
            'region': req.region,
            'district': req.district,
            'otherCategoryName': req.otherCategoryName,
            'submittedAt': Timestamp.fromDate(req.submittedAt),
            'status': 'approved',
            'reviewedAt': now,
            'reviewNote': 'Approved by admin',
          });
        } else {
          tx.update(requestRef, {
            'status': 'approved',
            'reviewedAt': now,
            'reviewNote': 'Approved by admin and added as category',
          });
        }

        // Update fundi's category field
        if (req.fundiId.isNotEmpty) {
          tx.update(fundiRef, {
            'category': categoryName,
            'otherCategoryName': null,
            'updatedAt': now,
          });
        }
      });

      if (!mounted) return;
      AppUtils.showSnackBar(context, '"$categoryName" approved and added.');
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        'Could not approve: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────

  Future<void> _reject(OtherCategoryRequest req) async {
    if (_busy) return;

    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Reject request?',
      message:
          'Reject "${req.otherCategoryName}" from ${req.fundiName.isEmpty ? 'this fundi' : req.fundiName}? '
          'Their category will remain as "Others".',
      confirmText: 'Reject',
      isDanger: true,
    );

    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;

      if (req.isSynthetic) {
        // Create a real doc with a Firestore-generated ID
        final ref =
            db.collection(FirestoreConstants.otherCategoryRequests).doc();
        await ref.set({
          'requestId': ref.id,
          'fundiId': req.fundiId,
          'fundiName': req.fundiName,
          'phone': req.phone,
          'region': req.region,
          'district': req.district,
          'otherCategoryName': req.otherCategoryName,
          'submittedAt': Timestamp.fromDate(req.submittedAt),
          'status': 'rejected',
          'reviewedAt': Timestamp.now(),
        });
      } else {
        await db
            .collection(FirestoreConstants.otherCategoryRequests)
            .doc(req.requestId)
            .update({
          'status': 'rejected',
          'reviewedAt': Timestamp.now(),
        });
      }

      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Request rejected.');
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Could not reject: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Restore to pending ────────────────────────────────────────────────────

  Future<void> _restoreToPending(OtherCategoryRequest req) async {
    if (req.isSynthetic) return; // already pending
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.otherCategoryRequests)
          .doc(req.requestId)
          .update({
        'status': 'pending',
        'reviewedAt': FieldValue.delete(),
        'reviewNote': FieldValue.delete(),
      });
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Moved back to pending.');
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Could not update: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _categoryDocId(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty
        ? 'category_${DateTime.now().millisecondsSinceEpoch}'
        : cleaned;
  }

  List<OtherCategoryRequest> _filterAndSort(
      List<OtherCategoryRequest> all) {
    final q = _query.trim().toLowerCase();
    var filtered = q.isEmpty
        ? all
        : all.where((r) {
            return r.fundiName.toLowerCase().contains(q) ||
                r.phone.toLowerCase().contains(q) ||
                r.region.toLowerCase().contains(q) ||
                r.district.toLowerCase().contains(q) ||
                r.otherCategoryName.toLowerCase().contains(q);
          }).toList();
    filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return filtered;
  }

  /// Merges request docs and fallback user docs, deduplicating by fundiId.
  List<OtherCategoryRequest> _mergeRequests(
    List<OtherCategoryRequest> fromRequests,
    List<OtherCategoryRequest> fromUsers,
  ) {
    final seen = <String>{};
    final merged = <OtherCategoryRequest>[];

    for (final r in fromRequests) {
      merged.add(r);
      if (r.fundiId.isNotEmpty) seen.add(r.fundiId);
    }
    for (final r in fromUsers) {
      if (!seen.contains(r.fundiId)) {
        merged.add(r);
      }
    }
    return merged;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Category Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child:
                  Center(child: AppLoader(size: 22, color: AppColors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          _Header(
            status: _status,
            onStatusChanged: (v) => setState(() => _status = v),
            onSearchChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _requestsStream,
              builder: (context, reqSnap) {
                // While waiting for the primary stream
                if (reqSnap.connectionState == ConnectionState.waiting &&
                    !reqSnap.hasData) {
                  return const AppLoaderCenter();
                }

                // Primary stream error
                if (reqSnap.hasError) {
                  return AppEmptyState(
                    icon: Icons.warning_amber_rounded,
                    title: 'Could not load requests',
                    subtitle:
                        'Check Firestore rules and your internet connection.\n'
                        'Error: ${reqSnap.error}',
                    iconColor: AppColors.error,
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  );
                }

                final reqDocs = reqSnap.data?.docs ?? [];
                final fromRequests = reqDocs.map((doc) {
                  final data = doc.data();
                  return OtherCategoryRequest.fromMap({
                    ...data,
                    'requestId': data['requestId'] ?? doc.id,
                  });
                }).toList();

                // For pending tab, also listen to users with category=Others
                if (_status == 'pending') {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fundiOthersStream,
                    builder: (context, userSnap) {
                      final fromUsers = <OtherCategoryRequest>[];

                      if (userSnap.hasData) {
                        for (final doc in userSnap.data!.docs) {
                          final data = doc.data();
                          final otherName =
                              (data['otherCategoryName'] ?? '').toString().trim();
                          if (otherName.isEmpty) continue;

                          // Only include if this fundi doesn't already
                          // have a request doc (dedup happens in _mergeRequests)
                          fromUsers.add(OtherCategoryRequest(
                            requestId:
                                'synthetic_${doc.id}', // extension detects this prefix
                            fundiId: doc.id,
                            fundiName: (data['fullName'] ?? '').toString(),
                            phone: (data['phone'] ?? '').toString(),
                            region: (data['region'] ?? '').toString(),
                            district: (data['district'] ?? '').toString(),
                            otherCategoryName: otherName,
                            submittedAt: data['updatedAt'] is Timestamp
                                ? (data['updatedAt'] as Timestamp).toDate()
                                : DateTime.now(),
                            status: 'pending',
                          ));
                        }
                      }

                      final merged =
                          _mergeRequests(fromRequests, fromUsers);
                      final filtered = _filterAndSort(merged);

                      if (filtered.isEmpty) {
                        return _EmptyState(
                            status: _status, hasQuery: _query.trim().isNotEmpty);
                      }

                      return _RequestList(
                        requests: filtered,
                        isBusy: _busy,
                        onApprove: _approve,
                        onReject: _reject,
                        onRestore: _restoreToPending,
                      );
                    },
                  );
                }

                // Approved / rejected tabs — no fallback needed
                final filtered = _filterAndSort(fromRequests);

                if (filtered.isEmpty) {
                  return _EmptyState(
                      status: _status, hasQuery: _query.trim().isNotEmpty);
                }

                return _RequestList(
                  requests: filtered,
                  isBusy: _busy,
                  onApprove: _approve,
                  onReject: _reject,
                  onRestore: _restoreToPending,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extended OtherCategoryRequest with isSynthetic flag
// ─────────────────────────────────────────────────────────────────────────────

extension OtherCategoryRequestX on OtherCategoryRequest {
  // Synthetic = built from users collection, no real doc in otherCategoryRequests yet.
  bool get isSynthetic => requestId.startsWith('synthetic_');
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable list widget
// ─────────────────────────────────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final List<OtherCategoryRequest> requests;
  final bool isBusy;
  final void Function(OtherCategoryRequest) onApprove;
  final void Function(OtherCategoryRequest) onReject;
  final void Function(OtherCategoryRequest) onRestore;

  const _RequestList({
    required this.requests,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceXXL,
          AppTheme.spaceLG,
          AppTheme.spaceXXL,
          110,
        ),
        itemCount: requests.length,
        itemBuilder: (_, i) {
          final req = requests[i];
          return _RequestCard(
            request: req,
            isBusy: isBusy,
            onApprove: () => onApprove(req),
            onReject: () => onReject(req),
            onRestore: () => onRestore(req),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header (search + status chips)
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.status,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review service category requests',
            style:
                AppTextStyles.titleLarge.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Approve fundis who chose "Others" and add their service as a real category.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.white.withOpacity(0.84)),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search name, phone, region, category...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                    label: 'Pending',
                    value: 'pending',
                    selected: status == 'pending',
                    onTap: onStatusChanged),
                _StatusChip(
                    label: 'Approved',
                    value: 'approved',
                    selected: status == 'approved',
                    onTap: onStatusChanged),
                _StatusChip(
                    label: 'Rejected',
                    value: 'rejected',
                    selected: status == 'rejected',
                    onTap: onStatusChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final ValueChanged<String> onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(value),
        selectedColor: AppColors.white,
        backgroundColor: AppColors.white.withOpacity(0.18),
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: selected ? AppColors.primary : AppColors.white,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: AppColors.white.withOpacity(0.35)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String status;
  final bool hasQuery;

  const _EmptyState({required this.status, required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    if (hasQuery) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching requests',
        subtitle:
            'Try another fundi name, phone, region, or category name.',
      );
    }
    switch (status) {
      case 'approved':
        return const AppEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'No approved requests yet',
          subtitle: 'Approved category requests will appear here.',
          iconColor: AppColors.success,
        );
      case 'rejected':
        return const AppEmptyState(
          icon: Icons.cancel_outlined,
          title: 'No rejected requests yet',
          subtitle: 'Rejected category requests will appear here.',
          iconColor: AppColors.error,
        );
      default:
        return const AppEmptyState(
          icon: Icons.category_outlined,
          title: 'No pending requests',
          subtitle:
              'When a fundi chooses "Others" during profile completion, '
              'their request will appear here.',
          iconColor: AppColors.primary,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request card
// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final OtherCategoryRequest request;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRestore;

  const _RequestCard({
    required this.request,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
    required this.onRestore,
  });

  bool get _isPending => request.status == 'pending';

  @override
  Widget build(BuildContext context) {
    final statusColor = request.status == 'approved'
        ? AppColors.success
        : request.status == 'rejected'
            ? AppColors.error
            : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(Icons.category_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.otherCategoryName.isEmpty
                          ? AppConstants.categoryOthers
                          : request.otherCategoryName,
                      style: AppTextStyles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'By ${request.fundiName.isEmpty ? 'Unknown fundi' : request.fundiName}',
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      request.status.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (request.isSynthetic) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'No request doc',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text:
                '${request.district.isEmpty ? '—' : request.district}, '
                '${request.region.isEmpty ? '—' : request.region}',
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.phone_outlined,
            text: request.phone.isEmpty
                ? 'No phone provided'
                : request.phone,
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.schedule_rounded,
            text: 'Submitted ${AppUtils.formatDateTime(request.submittedAt)}',
          ),
          const SizedBox(height: AppTheme.spaceMD),
          if (_isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRestore,
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('Move back to pending'),
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.grey500),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
