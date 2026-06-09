import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/fundi_model.dart';
import '../../models/reel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/cards/fundi_card.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_notif_bell.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/dashboard/client_search_bar.dart';
import '../../widgets/dashboard/promoted_fundis_section.dart';
import '../../widgets/common/app_loader.dart';
import 'all_categories_screen.dart';

// ── Category visual data ──────────────────────────────────────────────────────

class _CatMeta {
  final IconData icon;
  final Color color;
  final Color bg;
  const _CatMeta(this.icon, this.color, this.bg);
}

const _homeMeta = <String, _CatMeta>{
  'Plumber':             _CatMeta(Icons.water_drop_rounded,          Color(0xFF1565C0), Color(0xFFE3F2FD)),
  'Electrician':         _CatMeta(Icons.bolt_rounded,                Color(0xFFF57F17), Color(0xFFFFF8E1)),
  'Carpenter':           _CatMeta(Icons.carpenter_rounded,           Color(0xFF6D4C41), Color(0xFFEFEBE9)),
  'Cleaner':             _CatMeta(Icons.cleaning_services_rounded,   Color(0xFF00838F), Color(0xFFE0F7FA)),
  'Mechanic':            _CatMeta(Icons.build_rounded,               Color(0xFFAD1457), Color(0xFFFCE4EC)),
  'Painter':             _CatMeta(Icons.format_paint_rounded,        Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  'Beautician / Barber': _CatMeta(Icons.content_cut_rounded,        Color(0xFFAD1457), Color(0xFFFCE4EC)),
  'Mason / Builder':     _CatMeta(Icons.home_repair_service_rounded, Color(0xFF558B2F), Color(0xFFF1F8E9)),
};

_CatMeta _meta(String name) =>
    _homeMeta[name] ??
    const _CatMeta(Icons.handyman_rounded, Color(0xFF607D8B), Color(0xFFECEFF1));

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _State();
}

class _State extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _selCat;
  final _scrollController = ScrollController();
  final _fundiListKey     = GlobalKey();
  late final AnimationController _catAnim;

  @override
  void initState() {
    super.initState();
    _catAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().loadDashboard();
      context.read<ReelProvider>().subscribeApprovedReels();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _catAnim.dispose();
    super.dispose();
  }

  void _onFundiTap(FundiModel f) =>
      context.push('/client/fundi-details', extra: f);

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _FilterSheet(
        onApply: (region, district, rating, sortBy, nearby) => context
            .read<ClientProvider>()
            .applyFilters(
                category:     _selCat,
                region:       region,
                district:     district,
                minRating:    rating,
                sortBy:       sortBy,
                nearbyOption: nearby),
        onClear: () => context.read<ClientProvider>().clearFilters(),
      ),
    );
  }

  Future<void> _openAllCategories() async {
    final result = await Navigator.of(context).push<String?>(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            AllCategoriesScreen(initialCategory: _selCat),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
    if (!mounted) return;
    setState(() => _selCat = result);
  }

  void _selectHomeCategory(String name) {
    // Navigate to dedicated category screen with filtered fundi list
    context.push('/client/category-fundis', extra: name);
  }

  String _greeting(AppL10n l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.goodMorning;
    if (h < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final client = context.watch<ClientProvider>();
    final reelProv = context.watch<ReelProvider>();
    final user = auth.userModel;
    final l10n = AppL10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final approvedReels = reelProv.approvedReels;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => client.loadDashboard(),
        color: AppColors.primary,
        displacement: 60,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [

            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(top: -20, right: -20,
                        child: Container(width: 120, height: 120,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06)))),
                    Positioned(bottom: -30, right: 70,
                        child: Container(width: 70, height: 70,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05)))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/client/profile'),
                              child: AppAvatar(
                                imageUrl: user?.profileImageUrl,
                                name: user?.fullName ?? 'User',
                                size: 40,
                                backgroundColor: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting(l10n),
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white.withOpacity(0.75)),
                                  ),
                                  Text(
                                    user?.fullName.split(' ').first ?? 'there',
                                    style: AppTextStyles.titleLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const AppNotifBell(),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Find skilled professionals near you',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Search bar ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: ClientSearchBar(
                  onSearch: client.search,
                  onFilter: _showFilter,
                  hasActiveFilters: client.hasActiveFilters,
                ),
              ),
            ),

            // ── Categories header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Browse Categories',
                            style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                        Text(
                            '${AppConstants.serviceCategories.length} services available',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                    GestureDetector(
                      onTap: _openAllCategories,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text('View All',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 13, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category grid ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _HomeCategoryGrid(
                  categories: AppConstants.homeCategories,
                  selected: _selCat,
                  anim: _catAnim,
                  getMeta: _meta,
                  onTap: _selectHomeCategory,
                  onViewAll: _openAllCategories,
                ),
              ),
            ),

            // ── Active filter chip ──────────────────────────────────────
            if (_selCat != null &&
                !AppConstants.homeCategories.contains(_selCat))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selCat!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selCat = null);
                                client.selectCategory(null);
                              },
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Promoted fundis ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: PromotedFundisSection(
                  fundis: client.promotedFundis,
                  isLoading: client.isLoading,
                  onFundiTap: _onFundiTap,
                ),
              ),
            ),

            // ── Work Reels showcase ─────────────────────────────────────
            if (approvedReels.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE91E63),
                                          Color(0xFF9C27B0)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.play_circle_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Work Reels',
                                      style: AppTextStyles.titleMedium.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('See fundis in action',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/reels'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFE91E63),
                                  Color(0xFF9C27B0)
                                ]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Watch All',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: approvedReels.take(8).length,
                        itemBuilder: (context, i) {
                          final reel = approvedReels[i];
                          return _ReelPreviewCard(
                            reel: reel,
                            onTap: () => context.push('/reels'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // ── Fundi list header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selCat ?? 'Recommended Fundis',
                            style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _selCat != null
                                ? 'Top-rated ${_selCat!.toLowerCase()} professionals'
                                : 'Top-rated professionals near you',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (client.isSearching) const AppLoader(size: 18),
                  ],
                ),
              ),
            ),

            // ── Fundi list ──────────────────────────────────────────────
            if (client.isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const FundiCardShimmer(),
                    childCount: 4,
                  ),
                ),
              )
            else if (client.fundis.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: _EmptyFundis(
                    selCat: _selCat,
                    onClear: () {
                      setState(() => _selCat = null);
                      client.clearFilters();
                    },
                    onBrowseAll: _openAllCategories,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => FundiCard(
                      fundi: client.fundis[i],
                      onTap: () => _onFundiTap(client.fundis[i]),
                      clientLat: client.clientLat,
                      clientLng: client.clientLng,
                    ),
                    childCount: client.fundis.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

// ── Reel Preview Card ─────────────────────────────────────────────────────────

class _ReelPreviewCard extends StatelessWidget {
  final ReelModel reel;
  final VoidCallback onTap;

  const _ReelPreviewCard({required this.reel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty
                  ? Image.network(
                      reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _ReelFallback(reel.category),
                    )
                  : _ReelFallback(reel.category),

              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),

              // Play icon overlay
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.6), width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                ),
              ),

              // Bottom info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_rounded,
                                size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              reel.fundiName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          reel.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelFallback extends StatelessWidget {
  final String category;
  const _ReelFallback(this.category);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.7),
            AppColors.primary.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_rounded, size: 32, color: Colors.white70),
          const SizedBox(height: 4),
          Text(category,
              style: const TextStyle(
                  color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Home Category Grid (unchanged from original) ──────────────────────────────

class _HomeCategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final AnimationController anim;
  final _CatMeta Function(String) getMeta;
  final ValueChanged<String> onTap;
  final VoidCallback onViewAll;

  const _HomeCategoryGrid({
    required this.categories,
    required this.selected,
    required this.anim,
    required this.getMeta,
    required this.onTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cx) {
      const cols = 4;
      const gap = 10.0;
      final tileW = (cx.maxWidth - gap * (cols - 1)) / cols;
      final tileH = (tileW * 1.15).clamp(80.0, 110.0);

      final tiles = [...categories, '__more__'];

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(tiles.length, (i) {
          final name = tiles[i];
          final delay = (i * 55).clamp(0, 400);

          if (name == '__more__') {
            return AnimatedBuilder(
              animation: anim,
              builder: (_, child) {
                final raw =
                    ((anim.value * 1000 - delay) / 500).clamp(0.0, 1.0);
                final t = Curves.easeOutBack.transform(raw);
                return Opacity(
                    opacity: raw.clamp(0.0, 1.0),
                    child: Transform.scale(
                        scale: 0.6 + 0.4 * t, child: child));
              },
              child: _MoreTile(
                width: tileW,
                height: tileH,
                totalCount: AppConstants.serviceCategories.length,
                onTap: onViewAll,
              ),
            );
          }

          final m = getMeta(name);
          final isSel = selected == name;

          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) {
              final raw =
                  ((anim.value * 1000 - delay) / 500).clamp(0.0, 1.0);
              final t = Curves.easeOutBack.transform(raw);
              return Opacity(
                  opacity: raw.clamp(0.0, 1.0),
                  child:
                      Transform.scale(scale: 0.6 + 0.4 * t, child: child));
            },
            child: _HomeCatTile(
              name: name,
              meta: m,
              isSelected: isSel,
              width: tileW,
              height: tileH,
              onTap: () => onTap(name),
            ),
          );
        }),
      );
    });
  }
}

class _HomeCatTile extends StatefulWidget {
  final String name;
  final _CatMeta meta;
  final bool isSelected;
  final double width, height;
  final VoidCallback onTap;

  const _HomeCatTile({
    required this.name,
    required this.meta,
    required this.isSelected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_HomeCatTile> createState() => _HomeCatTileState();
}

class _HomeCatTileState extends State<_HomeCatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp: (_) => _press.forward(),
      onTapCancel: () => _press.forward(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.meta.color.withOpacity(0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected ? widget.meta.color : AppColors.border,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? widget.meta.color.withOpacity(0.18)
                    : AppColors.black.withOpacity(0.04),
                blurRadius: widget.isSelected ? 10 : 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.meta.color.withOpacity(0.2)
                      : widget.meta.bg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.meta.icon, color: widget.meta.color,
                    size: 20),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  widget.name.split(' ').first,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: widget.isSelected
                        ? widget.meta.color
                        : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatefulWidget {
  final double width, height;
  final int totalCount;
  final VoidCallback onTap;

  const _MoreTile({
    required this.width,
    required this.height,
    required this.totalCount,
    required this.onTap,
  });

  @override
  State<_MoreTile> createState() => _MoreTileState();
}

class _MoreTileState extends State<_MoreTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp: (_) => _press.forward(),
      onTapCancel: () => _press.forward(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _press,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.grid_view_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 5),
              const Text('More',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              Text(
                '+${widget.totalCount - AppConstants.homeCategories.length}',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withOpacity(0.65)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty fundis ──────────────────────────────────────────────────────────────

class _EmptyFundis extends StatelessWidget {
  final String? selCat;
  final VoidCallback onClear;
  final VoidCallback onBrowseAll;

  const _EmptyFundis({
    required this.selCat,
    required this.onClear,
    required this.onBrowseAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
                color: AppColors.primarySurface, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            selCat != null
                ? 'No "$selCat" fundis found'
                : 'No professionals found',
            style:
                AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            selCat != null
                ? 'Try another category or clear your filters'
                : 'Adjust your search or browse all categories',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded, size: 15),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onBrowseAll,
                  icon: const Icon(Icons.grid_view_rounded, size: 15),
                  label: const Text('Browse All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter Sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final void Function(String?, String?, double?, String, NearbyOption) onApply;
  final VoidCallback onClear;
  const _FilterSheet({required this.onApply, required this.onClear});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _region;
  double? _rating;
  String       _sortBy       = 'recommended';
  NearbyOption _nearbyOption = NearbyOption.anywhere;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(l10n.filterFundis,
                  style: AppTextStyles.titleMedium
                      .copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),
            // ── Sort By ─────────────────────────────────────────────────
            Text('Sort by',
                style: AppTextStyles.labelMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              for (final s in [
                ('recommended', 'Recommended'),
                ('rating',      'Top Rated'),
                ('jobs',        'Most Jobs'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _sortBy = s.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: _sortBy == s.$1
                            ? AppColors.primary : AppColors.grey100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(s.$2, style: TextStyle(
                        color: _sortBy == s.$1
                            ? Colors.white : AppColors.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w700,
                      )),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 16),

            // ── Distance / Nearby ─────────────────────────────────────────
            Text('Distance',
                style: AppTextStyles.labelMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: NearbyOption.values.map((opt) {
                final sel = _nearbyOption == opt;
                return GestureDetector(
                  onTap: () => setState(() => _nearbyOption = opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(opt.label, style: TextStyle(
                      color: sel ? Colors.white : AppColors.textPrimary,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _region,
              decoration: InputDecoration(
                labelText: 'Region',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              hint: Text(l10n.allRegions),
              items: AppConstants.tanzaniaRegions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _region = v),
            ),
            const SizedBox(height: 16),
            Text(l10n.minimumRating,
                style: AppTextStyles.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [1, 2, 3, 4, 5].map((r) {
                final sel = _rating == r.toDouble();
                return GestureDetector(
                  onTap: () =>
                      setState(() => _rating = sel ? null : r.toDouble()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.grey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded,
                          size: 13,
                          color: sel ? Colors.white : AppColors.grey500),
                      const SizedBox(width: 3),
                      Text('$r+',
                          style: TextStyle(
                            color: sel ? Colors.white : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: Text(l10n.clearAll),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onApply(_region, null, _rating, _sortBy, _nearbyOption);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(l10n.applyFilters),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
