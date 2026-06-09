import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/fundi_model.dart';
import '../../providers/client_provider.dart';
import '../../widgets/cards/fundi_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

/// Dedicated screen showing fundis filtered by [category].
/// Supports Sort By, Distance, Region, and Minimum Rating.
class CategoryFundisScreen extends StatefulWidget {
  final String category;
  const CategoryFundisScreen({super.key, required this.category});

  @override
  State<CategoryFundisScreen> createState() => _CategoryFundisScreenState();
}

class _CategoryFundisScreenState extends State<CategoryFundisScreen> {
  final _scrollCtrl  = ScrollController();
  final _resultsKey  = GlobalKey();
  final _searchCtrl  = TextEditingController();
  String _query = '';

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      } else if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().applyFilters(
            category: widget.category,
            sortBy: 'recommended',
          );
    _scrollToResults();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().selectCategory(null);
    });
    super.dispose();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFilterSheet(category: widget.category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ClientProvider>();
    final fundis = cp.fundis;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
            onPressed: _showFilters,
          ),
        ],
      ),
      body: cp.isSearching
          ? const AppLoaderCenter()
          : fundis.isEmpty
              ? AppEmptyState(
                  icon:     Icons.person_search_rounded,
                  title:    'No ${widget.category}s Found',
                  subtitle: 'Try adjusting your filters or check back later.',
                  iconColor: AppColors.primary,
                )
              : Column(
                  children: [
                    // Active filter chips
                    if (cp.hasActiveFilters)
                      _ActiveFilterBar(provider: cp, category: widget.category),

                    // Search bar + result count
                    Padding(
                      key: _resultsKey,
                      padding: const EdgeInsets.fromLTRB(
                          AppTheme.spaceLG, AppTheme.spaceMD,
                          AppTheme.spaceLG, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Inline search
                          TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search in ${widget.category}...',
                              prefixIcon: const Icon(
                                  Icons.search_rounded, size: 20),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _query = '');
                                        context.read<ClientProvider>()
                                            .applyFilters(
                                              category: widget.category,
                                              sortBy: 'recommended',
                                            );
                                      })
                                  : null,
                              filled: true,
                              fillColor: AppColors.grey100,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                            ),
                            onChanged: (v) {
                              setState(() => _query = v);
                              context.read<ClientProvider>().search(v);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${fundis.length} fundi${fundis.length == 1 ? '' : 's'} found',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spaceLG),
                        itemCount: fundis.length,
                        itemBuilder: (_, i) {
                          final fundi = fundis[i];
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.spaceMD),
                            child: FundiCard(
                              fundi:     fundi,
                              clientLat: cp.clientLat,
                              clientLng: cp.clientLng,
                              onTap: () => context.push(
                                  '/client/fundi-details',
                                  extra: fundi),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Active filter chips bar ───────────────────────────────────────────────────

class _ActiveFilterBar extends StatelessWidget {
  final ClientProvider provider;
  final String         category;

  const _ActiveFilterBar(
      {required this.provider, required this.category});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (provider.sortBy != 'recommended') {
      chips.add(_FilterChip(
        label: provider.sortBy == 'rating' ? 'Top Rated' : 'Most Jobs',
        onRemove: () => context.read<ClientProvider>().applyFilters(
              category: category,
              sortBy:   'recommended',
            ),
      ));
    }
    if (provider.nearbyOption != NearbyOption.anywhere) {
      chips.add(_FilterChip(
        label:    provider.nearbyOption.label,
        onRemove: () => context.read<ClientProvider>().applyFilters(
              category:     category,
              nearbyOption: NearbyOption.anywhere,
            ),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceLG, AppTheme.spaceSM, AppTheme.spaceLG, 0),
      child: Row(children: chips),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label:            Text(label, style: AppTextStyles.caption),
          deleteIcon:       const Icon(Icons.close_rounded, size: 14),
          onDeleted:        onRemove,
          backgroundColor:  AppColors.primarySurface,
          deleteIconColor:  AppColors.primary,
          labelStyle:       AppTextStyles.caption
              .copyWith(color: AppColors.primary),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
        ),
      );
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _CategoryFilterSheet extends StatefulWidget {
  final String category;
  const _CategoryFilterSheet({required this.category});

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  String       _sortBy  = 'recommended';
  NearbyOption _nearby  = NearbyOption.anywhere;
  double?      _rating;
  String?      _region;

  @override
  void initState() {
    super.initState();
    final cp = context.read<ClientProvider>();
    _sortBy  = cp.sortBy;
    _nearby  = cp.nearbyOption;
    _region  = cp.selectedRegion;
  }

  void _apply() {
    context.read<ClientProvider>().applyFilters(
          category:     widget.category,
          sortBy:       _sortBy,
          nearbyOption: _nearby,
          minRating:    _rating,
          region:       _region,
        );
    Navigator.pop(context);
  }

  void _clear() {
    context.read<ClientProvider>().applyFilters(
          category: widget.category,
          sortBy:   'recommended',
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      expand:           false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin:     const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Filter Fundis',
                  style: AppTextStyles.titleSmall
                      .copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          const Divider(height: 20),

          // Scrollable filter body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [

                // ── Sort by ──────────────────────────────────────────
                Text('Sort by',
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  for (final s in [
                    ('recommended', 'Recommended'),
                    ('rating',      'Top Rated'),
                    ('jobs',        'Most Jobs'),
                  ])
                    _ChoiceChip(
                      label:    s.$2,
                      selected: _sortBy == s.$1,
                      onTap:    () => setState(() => _sortBy = s.$1),
                    ),
                ]),
                const SizedBox(height: 20),

                // ── Distance ─────────────────────────────────────────
                Text('Distance',
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: NearbyOption.values.map((opt) => _ChoiceChip(
                    label:    opt.label,
                    selected: _nearby == opt,
                    onTap:    () => setState(() => _nearby = opt),
                  )).toList(),
                ),
                const SizedBox(height: 20),

                // ── Minimum rating ────────────────────────────────────
                Text('Minimum Rating',
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in [null, 1.0, 2.0, 3.0, 4.0, 5.0])
                      _ChoiceChip(
                        label:    r == null ? 'Any' : '${r.toInt()}+★',
                        selected: _rating == r,
                        onTap:    () => setState(() => _rating = r),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Region ────────────────────────────────────────────
                Text('Region',
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _region,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    hintText:     'All Regions',
                    border:       OutlineInputBorder(),
                    isDense:      true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Regions')),
                    ...AppConstants.tanzaniaRegions.map(
                      (r) => DropdownMenuItem(value: r, child: Text(r)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _region = v),
                ),
              ],
            ),
          ),

          // Action buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clear,
                    icon:  const Icon(Icons.clear_rounded),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _apply,
                    icon:  const Icon(Icons.check_rounded),
                    label: const Text('Apply Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _ChoiceChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:        selected ? AppColors.primary : AppColors.grey100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:      selected ? Colors.white : AppColors.textPrimary,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}
