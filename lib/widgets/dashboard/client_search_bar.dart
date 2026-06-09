import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ClientSearchBar extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onFilter;
  final bool hasActiveFilters;

  const ClientSearchBar({
    super.key,
    required this.onSearch,
    required this.onFilter,
    this.hasActiveFilters = false,
  });

  @override
  State<ClientSearchBar> createState() => _ClientSearchBarState();
}

class _ClientSearchBarState extends State<ClientSearchBar>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final AnimationController _focusAnim;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController();
    _focus = FocusNode();
    _focusAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _focus.addListener(() {
      if (_focus.hasFocus) _focusAnim.forward();
      else _focusAnim.reverse();
    });
    _ctrl.addListener(() {
      final has = _ctrl.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _focusAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnim,
      builder: (_, child) {
        final t         = _focusAnim.value;
        final borderClr = AppColors.border;   // always grey — no blue on focus
        final borderW   = 0.9 + 0.3 * t;     // 0.9 resting → 1.2 focused

        return Container(
          height: 56,   // ← taller, easier to tap, fills width well
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(99),   // pill
            border:       Border.all(color: borderClr, width: borderW),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
              // no focus glow
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          const SizedBox(width: 18),
          AnimatedBuilder(
            animation: _focusAnim,
            builder: (_, __) => const Icon(
              Icons.search_rounded,
              size:  22,
              color: AppColors.grey500,   // always grey
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller:      _ctrl,
              focusNode:       _focus,
              onChanged:       widget.onSearch,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodyMedium.copyWith(
                color:      AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize:   17,
              ),
              decoration: InputDecoration(
                hintText: 'Search plumber, electrician...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color:    AppColors.textHint,
                  fontSize:   17,
                ),
                border:         InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          if (_hasText) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { _ctrl.clear(); widget.onSearch(''); },
              child: Container(
                width:  28,
                height: 28,
                decoration: const BoxDecoration(
                    color: AppColors.grey200, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.grey600),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(width: 1, height: 24, color: AppColors.border),
          const SizedBox(width: 10),
          // Filter button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap:    widget.onFilter,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration:     const Duration(milliseconds: 180),
                  width:        38,
                  height:       38,
                  decoration:   BoxDecoration(
                    color: widget.hasActiveFilters
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size:  20,
                    color: widget.hasActiveFilters
                        ? AppColors.primary
                        : AppColors.grey600,
                  ),
                ),
                if (widget.hasActiveFilters)
                  Positioned(
                    top:   -3,
                    right: -3,
                    child: Container(
                      width:  9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: AppColors.secondary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
