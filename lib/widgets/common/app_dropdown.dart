import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String label;
  final String? hint;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  const AppDropdown({super.key,required this.value,required this.items,required this.label,this.hint,required this.itemLabel,required this.onChanged,this.validator,this.enabled=true});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value:value,validator:validator,isExpanded:true,icon:const Icon(Icons.keyboard_arrow_down_rounded),
      decoration:InputDecoration(labelText:label,hintText:hint??'Select \$label'),
      style:AppTextStyles.bodyMedium,dropdownColor:AppColors.surface,
      borderRadius:BorderRadius.circular(AppTheme.radiusMD),
      items:items.map((item)=>DropdownMenuItem<T>(value:item,child:Text(itemLabel(item),style:AppTextStyles.bodyMedium,overflow:TextOverflow.ellipsis))).toList(),
      onChanged:enabled?onChanged:null,
    );
  }
}