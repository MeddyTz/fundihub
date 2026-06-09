import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

class ChatDateDivider extends StatelessWidget {
  final DateTime date;
  const ChatDateDivider({super.key,required this.date});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:const EdgeInsets.symmetric(vertical:AppTheme.spaceMD),
      child:Row(children:[
        const Expanded(child:Divider()),
        Padding(padding:const EdgeInsets.symmetric(horizontal:AppTheme.spaceMD),
          child:Container(padding:const EdgeInsets.symmetric(horizontal:AppTheme.spaceMD,vertical:AppTheme.spaceXS),decoration:BoxDecoration(color:AppColors.grey100,borderRadius:BorderRadius.circular(AppTheme.radiusFull)),
            child:Text(AppUtils.formatChatDate(date),style:AppTextStyles.caption.copyWith(fontWeight:FontWeight.w500)))),
        const Expanded(child:Divider()),
      ]),
    );
  }
}