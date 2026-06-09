import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
enum BadgeType { premium, promoted, free, verified, new_, active, inactive }
class AppBadge extends StatelessWidget {
  final BadgeType type;
  final String? customLabel;
  final double? fontSize;
  const AppBadge({super.key,required this.type,this.customLabel,this.fontSize});
  @override
  Widget build(BuildContext context) {
    final c=_cfg();
    return Container(padding:const EdgeInsets.symmetric(horizontal:AppTheme.spaceSM+2,vertical:AppTheme.spaceXXS+1),decoration:BoxDecoration(color:c.bg,borderRadius:BorderRadius.circular(AppTheme.radiusFull),border:c.border!=null?Border.all(color:c.border!,width:1):null),child:Row(mainAxisSize:MainAxisSize.min,children:[if(c.icon!=null)...[Icon(c.icon,size:10,color:c.fg),const SizedBox(width:3)],Text(customLabel??c.label,style:AppTextStyles.caption.copyWith(color:c.fg,fontWeight:FontWeight.w600,fontSize:fontSize??10))]));
  }
  _BC _cfg() {
    switch(type) {
      case BadgeType.premium: return _BC('Premium',AppColors.premium,AppColors.white,Icons.star_rounded);
      case BadgeType.promoted: return _BC('Promoted',AppColors.promoted,AppColors.white,Icons.rocket_launch_rounded);
      case BadgeType.free: return _BC('Free',AppColors.grey200,AppColors.grey700,null);
      case BadgeType.verified: return _BC('Verified',AppColors.successSurface,AppColors.success,Icons.verified_rounded,AppColors.success.withOpacity(0.3));
      case BadgeType.new_: return _BC('New',AppColors.secondarySurface,AppColors.secondary,null,AppColors.secondary.withOpacity(0.3));
      case BadgeType.active: return _BC('Active',AppColors.successSurface,AppColors.success,null);
      case BadgeType.inactive: return _BC('Inactive',AppColors.grey100,AppColors.grey600,null);
    }
  }
}
class _BC { final String label; final Color bg,fg; final IconData? icon; final Color? border; const _BC(this.label,this.bg,this.fg,this.icon,[this.border]); }