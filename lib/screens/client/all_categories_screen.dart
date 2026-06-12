import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

// ── Category visual meta ──────────────────────────────────────────────────────

class _CategoryMeta {
  final IconData icon;
  final Color color;
  final Color background;
  const _CategoryMeta(this.icon, this.color, this.background);
}

const Map<String, _CategoryMeta> _categoryMeta = {
  'Plumber': _CategoryMeta(Icons.plumbing_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'Electrician': _CategoryMeta(Icons.bolt_rounded, Color(0xFFF57F17), Color(0xFFFFF8E1)),
  'Carpenter': _CategoryMeta(Icons.carpenter_rounded, Color(0xFF6D4C41), Color(0xFFEFEBE9)),
  'Painter': _CategoryMeta(Icons.format_paint_rounded, Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  'Mason / Builder': _CategoryMeta(Icons.home_repair_service_rounded, Color(0xFF558B2F), Color(0xFFF1F8E9)),
  'Welder': _CategoryMeta(Icons.whatshot_rounded, Color(0xFFBF360C), Color(0xFFFBE9E7)),
  'Roofer': _CategoryMeta(Icons.roofing_rounded, Color(0xFF37474F), Color(0xFFECEFF1)),
  'Tiler': _CategoryMeta(Icons.grid_view_rounded, Color(0xFF00695C), Color(0xFFE0F2F1)),
  'Flooring Specialist': _CategoryMeta(Icons.layers_rounded, Color(0xFF4E342E), Color(0xFFEFEBE9)),
  'Ceiling & Partitioning': _CategoryMeta(Icons.cabin_rounded, Color(0xFF455A64), Color(0xFFECEFF1)),
  'Waterproofing': _CategoryMeta(Icons.water_rounded, Color(0xFF0277BD), Color(0xFFE1F5FE)),
  'Glass & Aluminium Works': _CategoryMeta(Icons.window_rounded, Color(0xFF006064), Color(0xFFE0F7FA)),
  'Fence & Gate Installation': _CategoryMeta(Icons.fence_rounded, Color(0xFF5D4037), Color(0xFFEFEBE9)),
  'Locksmith': _CategoryMeta(Icons.lock_rounded, Color(0xFF424242), Color(0xFFF5F5F5)),
  'AC / Refrigeration Technician': _CategoryMeta(Icons.ac_unit_rounded, Color(0xFF0277BD), Color(0xFFE1F5FE)),
  'Electronics Technician': _CategoryMeta(Icons.electrical_services_rounded, Color(0xFF6A1B9A), Color(0xFFEDE7F6)),
  'Solar Panel Technician': _CategoryMeta(Icons.solar_power_rounded, Color(0xFFF9A825), Color(0xFFFFFDE7)),
  'Generator Technician': _CategoryMeta(Icons.power_rounded, Color(0xFF558B2F), Color(0xFFF1F8E9)),
  'Internet / Network Technician': _CategoryMeta(Icons.wifi_rounded, Color(0xFF00695C), Color(0xFFE0F2F1)),
  'DSTV / TV Antenna Installation': _CategoryMeta(Icons.satellite_alt_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'Phone Repair': _CategoryMeta(Icons.phone_android_rounded, Color(0xFF2E7D32), Color(0xFFE8F5E9)),
  'Laptop Repair': _CategoryMeta(Icons.laptop_rounded, Color(0xFF37474F), Color(0xFFECEFF1)),
  'Printer / Copier Technician': _CategoryMeta(Icons.print_rounded, Color(0xFF4527A0), Color(0xFFEDE7F6)),
  'CCTV / Security Systems': _CategoryMeta(Icons.videocam_rounded, Color(0xFF37474F), Color(0xFFECEFF1)),
  'Cleaner': _CategoryMeta(Icons.cleaning_services_rounded, Color(0xFF00838F), Color(0xFFE0F7FA)),
  'Deep Cleaning': _CategoryMeta(Icons.sanitizer_rounded, Color(0xFF00ACC1), Color(0xFFE0F7FA)),
  'Fumigation / Pest Control': _CategoryMeta(Icons.bug_report_rounded, Color(0xFF558B2F), Color(0xFFF1F8E9)),
  'Gardener': _CategoryMeta(Icons.yard_rounded, Color(0xFF2E7D32), Color(0xFFE8F5E9)),
  'Pool Maintenance': _CategoryMeta(Icons.pool_rounded, Color(0xFF0288D1), Color(0xFFE1F5FE)),
  'Mechanic': _CategoryMeta(Icons.build_rounded, Color(0xFFAD1457), Color(0xFFFCE4EC)),
  'Auto Electrician': _CategoryMeta(Icons.car_repair_rounded, Color(0xFF6A1B9A), Color(0xFFEDE7F6)),
  'Car Wash / Detailing': _CategoryMeta(Icons.local_car_wash_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'Tyre & Puncture Repair': _CategoryMeta(Icons.tire_repair_rounded, Color(0xFF37474F), Color(0xFFECEFF1)),
  'Windscreen Repair': _CategoryMeta(Icons.time_to_leave_rounded, Color(0xFF00695C), Color(0xFFE0F2F1)),
  'Driver': _CategoryMeta(Icons.drive_eta_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'Delivery / Courier': _CategoryMeta(Icons.delivery_dining_rounded, Color(0xFFFF6F00), Color(0xFFFFF8E1)),
  'Beautician / Barber': _CategoryMeta(Icons.content_cut_rounded, Color(0xFFAD1457), Color(0xFFFCE4EC)),
  'Nurse / Caregiver': _CategoryMeta(Icons.medical_services_rounded, Color(0xFFC62828), Color(0xFFFFEBEE)),
  'Massage Therapist': _CategoryMeta(Icons.spa_rounded, Color(0xFF6A1B9A), Color(0xFFEDE7F6)),
  'Physiotherapist': _CategoryMeta(Icons.accessibility_new_rounded, Color(0xFF00838F), Color(0xFFE0F7FA)),
  'Photographer': _CategoryMeta(Icons.camera_alt_rounded, Color(0xFF37474F), Color(0xFFECEFF1)),
  'Videographer': _CategoryMeta(Icons.videocam_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'DJ / Sound System': _CategoryMeta(Icons.queue_music_rounded, Color(0xFF6A1B9A), Color(0xFFEDE7F6)),
  'Event Planner': _CategoryMeta(Icons.celebration_rounded, Color(0xFFFF6F00), Color(0xFFFFF8E1)),
  'Tent & Chairs Rental': _CategoryMeta(Icons.chair_rounded, Color(0xFF558B2F), Color(0xFFF1F8E9)),
  'MC / Host': _CategoryMeta(Icons.mic_rounded, Color(0xFFC62828), Color(0xFFFFEBEE)),
  'Wedding Decorator': _CategoryMeta(Icons.favorite_rounded, Color(0xFFAD1457), Color(0xFFFCE4EC)),
  'Tutor / Teacher': _CategoryMeta(Icons.school_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'Chef / Catering': _CategoryMeta(Icons.restaurant_rounded, Color(0xFFFF6F00), Color(0xFFFFF8E1)),
  'Tailor / Seamstress': _CategoryMeta(Icons.checkroom_rounded, Color(0xFF4527A0), Color(0xFFEDE7F6)),
  'Accountant': _CategoryMeta(Icons.calculate_rounded, Color(0xFF2E7D32), Color(0xFFE8F5E9)),
  'Others': _CategoryMeta(Icons.more_horiz_rounded, Color(0xFF607D8B), Color(0xFFECEFF1)),
};

const _fallbackMeta = _CategoryMeta(
    Icons.handyman_rounded, Color(0xFF607D8B), Color(0xFFECEFF1));

// ── Screen ────────────────────────────────────────────────────────────────────

class AllCategoriesScreen extends StatefulWidget {
  final String? initialCategory;
  const AllCategoriesScreen({super.key, this.initialCategory});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String  _query    = '';
  String? _selected;

  // Admin-approved custom categories from Firestore (not in hardcoded list)
  List<String> _approvedCustom = [];
  bool _loadingCustom = true;

  // Hardcoded default category names (lowercased set for fast lookup)
  late final Set<String> _defaultLower;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCategory;

    // Build a set of all default category names in lowercase for comparison
    final all = AppConstants.categoryGroups.values.expand((e) => e).toSet();
    _defaultLower = all.map((c) => c.trim().toLowerCase()).toSet();

    _fetchApprovedCustomCategories();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Fetch approved custom categories from Firestore ────────────────────────
  Future<void> _fetchApprovedCustomCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreConstants.categories)
          .where('isActive', isEqualTo: true)
          .get();

      final names = snap.docs
          .map((d) => (d.data()['name'] as String? ?? '').trim())
          .where((n) => n.isNotEmpty)
          // Only include categories NOT already in the hardcoded list
          .where((n) => !_defaultLower.contains(n.toLowerCase()))
          .toSet()
          .toList()
        ..sort();

      if (mounted) {
        setState(() {
          _approvedCustom  = names;
          _loadingCustom   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCustom = false);
    }
  }

  // ── Build combined category groups ────────────────────────────────────────
  Map<String, List<String>> get _allGroups {
    final base = AppConstants.categoryGroups.isNotEmpty
        ? Map<String, List<String>>.from(AppConstants.categoryGroups)
        : <String, List<String>>{'All Services': AppConstants.serviceCategories};

    if (_approvedCustom.isNotEmpty) {
      // Inject approved custom categories into a dedicated group
      base['Custom Services'] = List<String>.from(_approvedCustom);
    }

    return base;
  }

  List<String> get _allCategoryNames {
    final all = _allGroups.values.expand((e) => e).toSet().toList();
    return all;
  }

  // ── Filter groups by search query ─────────────────────────────────────────
  Map<String, List<String>> get _filteredGroups {
    final groups = _allGroups;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return groups;

    final filtered = <String, List<String>>{};
    for (final entry in groups.entries) {
      final matches = entry.value
          .where((name) => name.trim().toLowerCase().contains(q))
          .toList(growable: false);
      if (matches.isNotEmpty) filtered[entry.key] = matches;
    }
    return filtered;
  }

  int get _shownCount =>
      _filteredGroups.values.fold<int>(0, (s, cats) => s + cats.length);

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _selectCategory(String? category) {
    if (category == null) { setState(() => _selected = null); return; }
    context.push('/client/category-fundis', extra: category);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  void _close() => Navigator.of(context).pop(_selected);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final groups    = _filteredGroups;
    final topPad    = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      // KEY FIX: prevent scaffold from resizing when keyboard opens.
      // The Expanded + ListView inside already handles scrolling.
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Fixed header + search ─────────────────────────────────────
          _CategoriesHeader(
            topPadding:       topPad,
            searchController: _searchCtrl,
            query:            _query,
            selected:         _selected,
            totalCategories:  _allCategoryNames.length,
            isLoading:        _loadingCustom,
            onBack:           _close,
            onClearSelected:  () => _selectCategory(null),
            onClearSearch:    _clearSearch,
            onChanged:        (v) => setState(() => _query = v),
          ),
          // ── Scrollable results ────────────────────────────────────────
          Expanded(
            child: _loadingCustom && _query.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                    ? _EmptyCategoriesState(query: _query, onClear: _clearSearch)
                    : ListView.builder(
                        // Use keyboard-aware padding so list scrolls above keyboard
                        padding: EdgeInsets.fromLTRB(
                            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 96 + bottomPad),
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final entry = groups.entries.elementAt(index);
                          return _CategoryGroup(
                            title:      entry.key,
                            categories: entry.value,
                            selected:   _selected,
                            onSelected: (v) =>
                                _selectCategory(_selected == v ? null : v),
                          );
                        },
                      ),
          ),
        ],
      ),
      // ── Sticky bottom bar ─────────────────────────────────────────────
      bottomNavigationBar: _CategoriesBottomBar(
        bottomPadding: bottomPad,
        selected:      _selected,
        shownCount:    _shownCount,
        onDone:        _close,
      ),
    );
  }
}

// ── Header + search ───────────────────────────────────────────────────────────

class _CategoriesHeader extends StatelessWidget {
  final double topPadding;
  final TextEditingController searchController;
  final String query;
  final String? selected;
  final int totalCategories;
  final bool isLoading;
  final VoidCallback onBack, onClearSelected, onClearSearch;
  final ValueChanged<String> onChanged;

  const _CategoriesHeader({
    required this.topPadding,
    required this.searchController,
    required this.query,
    required this.selected,
    required this.totalCategories,
    required this.isLoading,
    required this.onBack,
    required this.onClearSelected,
    required this.onClearSearch,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 12, 18, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Material(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('All Categories',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   24,
                    fontWeight: FontWeight.w800,
                    height:     1.0,
                  )),
              const SizedBox(height: 6),
              Text(
                isLoading
                    ? 'Loading...'
                    : '$totalCategories services available',
                style: TextStyle(
                  color:      Colors.white.withOpacity(.80),
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
          if (selected != null)
            TextButton(
              onPressed: onClearSelected,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(.16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Clear'),
            ),
        ]),
        const SizedBox(height: 18),
        // ── Search bar ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(.10),
                blurRadius: 18,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller:     searchController,
            onChanged:      onChanged,
            textInputAction: TextInputAction.search,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            // Dismiss keyboard on submit — keeps results visible
            onSubmitted: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              prefixIcon: Icon(Icons.search_rounded,
                  color: query.isEmpty
                      ? AppColors.grey400
                      : AppColors.primary),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.grey600),
                    ),
              filled:      true,
              fillColor:   Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide:   BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide:   BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Category group ────────────────────────────────────────────────────────────

class _CategoryGroup extends StatelessWidget {
  final String title;
  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _CategoryGroup({
    required this.title,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              color:        AppColors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: AppTextStyles.titleSmall)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        AppColors.primarySurface,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${categories.length}',
              style: AppTextStyles.caption.copyWith(
                color:      AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:  3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (_, i) {
            final name = categories[i];
            return _CategoryTile(
              name:       name,
              meta:       _categoryMeta[name] ?? _fallbackMeta,
              isSelected: selected == name,
              onTap:      () => onSelected(name),
            );
          },
        ),
      ]),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String name;
  final _CategoryMeta meta;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.meta,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? meta.color.withOpacity(.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? meta.color : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? meta.color.withOpacity(.18)
                    : Colors.black.withOpacity(.04),
                blurRadius: isSelected ? 16 : 10,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width:  46,
                height: 46,
                decoration: BoxDecoration(
                  color:        meta.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(meta.icon, color: meta.color, size: 25),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color:      isSelected ? meta.color : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  height:     1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _CategoriesBottomBar extends StatelessWidget {
  final double bottomPadding;
  final String? selected;
  final int shownCount;
  final VoidCallback onDone;

  const _CategoriesBottomBar({
    required this.bottomPadding,
    required this.selected,
    required this.shownCount,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset:     const Offset(0, -6),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected == null ? 'All services' : 'Selected: $selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color:      selected == null
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text('$shownCount categories shown',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(130, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(selected == null ? 'Show All' : 'Show Fundis'),
        ),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCategoriesState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const _EmptyCategoriesState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 86, height: 86,
            decoration: const BoxDecoration(
              color:  AppColors.primarySurface,
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 18),
          Text(
            query.trim().isEmpty
                ? 'No categories available'
                : 'No categories found for "$query"',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try another keyword or clear your search.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          if (query.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onClear,
              icon:  const Icon(Icons.close_rounded),
              label: const Text('Clear search'),
            ),
          ],
        ]),
      ),
    );
  }
}
