import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint,initialValue;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText,enabled,readOnly;
  final int? maxLines,minLines,maxLength;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged,onSubmitted;
  final void Function()? onTap;
  final FocusNode? focusNode;
  final EdgeInsets? contentPadding;
  const AppTextField({super.key,this.controller,required this.label,this.hint,this.validator,this.keyboardType=TextInputType.text,this.textInputAction=TextInputAction.next,this.obscureText=false,this.enabled=true,this.maxLines=1,this.minLines,this.maxLength,this.prefixIcon,this.suffixWidget,this.inputFormatters,this.onChanged,this.onSubmitted,this.onTap,this.readOnly=false,this.focusNode,this.initialValue,this.contentPadding});
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}
class _AppTextFieldState extends State<AppTextField> {
  bool _obscure=false;
  @override void initState() { super.initState(); _obscure=widget.obscureText; }
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:widget.controller,initialValue:widget.initialValue,validator:widget.validator,
      keyboardType:widget.keyboardType,textInputAction:widget.textInputAction,
      obscureText:_obscure,enabled:widget.enabled,maxLines:widget.obscureText?1:widget.maxLines,
      minLines:widget.minLines,maxLength:widget.maxLength,inputFormatters:widget.inputFormatters,
      onChanged:widget.onChanged,onFieldSubmitted:widget.onSubmitted,onTap:widget.onTap,
      readOnly:widget.readOnly,focusNode:widget.focusNode,style:AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText:widget.label,hintText:widget.hint,contentPadding:widget.contentPadding,counterText:'',
        prefixIcon:widget.prefixIcon!=null?Icon(widget.prefixIcon,size:20):null,
        suffixIcon:widget.obscureText?IconButton(icon:Icon(_obscure?Icons.visibility_off:Icons.visibility,size:20,color:AppColors.grey500),onPressed:()=>setState(()=>_obscure=!_obscure)):widget.suffixWidget,
      ),
    );
  }
}