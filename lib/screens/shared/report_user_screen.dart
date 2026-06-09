import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;
  final String? relatedBookingId;
  const ReportUserScreen({super.key,required this.reportedUserId,required this.reportedUserName,this.relatedBookingId});
  @override State<ReportUserScreen> createState() => _State();
}
class _State extends State<ReportUserScreen> {
  String? _reason;
  final _detailsCtrl=TextEditingController();
  final _reasons=['Fraud / Scam','Inappropriate Behavior','No-show','Poor Quality Work','Harassment','Fake Profile','Other'];
  @override void dispose() { _detailsCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if(_reason==null){AppUtils.showSnackBar(context,'Please select a reason',isError:true);return;}
    if(_detailsCtrl.text.trim().length<10){AppUtils.showSnackBar(context,'Please provide more details',isError:true);return;}
    final auth=context.read<AuthProvider>();
    final prov=context.read<ReviewProvider>();
    if(auth.userModel==null) return;
    final ok=await prov.submitReport(reporterId:auth.userModel!.uid,reporterName:auth.userModel!.fullName,reportedUserId:widget.reportedUserId,reportedUserName:widget.reportedUserName,reason:_reason!,details:_detailsCtrl.text.trim(),relatedBookingId:widget.relatedBookingId);
    if(!mounted) return;
    if(ok){
      showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Report Submitted'),content:const Text('Thank you. Our team will review this report within 24 hours.'),actions:[ElevatedButton(onPressed:(){Navigator.pop(context);context.pop();},child:const Text('OK'))]));
    } else AppUtils.showSnackBar(context,prov.errorMessage??'Failed to submit',isError:true);
  }

  @override
  Widget build(BuildContext context) {
    final prov=context.watch<ReviewProvider>();
    return AppLoadingOverlay(isLoading:prov.isSubmitting,message:'Submitting report...',child:Scaffold(
      backgroundColor:AppColors.background,
      appBar:AppBar(title:const Text('Report User'),backgroundColor:AppColors.primary,leading:IconButton(icon:const Icon(Icons.arrow_back_rounded),onPressed:()=>context.pop())),
      body:SingleChildScrollView(padding:const EdgeInsets.all(AppTheme.spaceXXL),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Container(padding:const EdgeInsets.all(AppTheme.spaceLG),decoration:BoxDecoration(color:AppColors.errorSurface,borderRadius:BorderRadius.circular(AppTheme.radiusXL),border:Border.all(color:AppColors.error.withOpacity(0.3))),child:Row(children:[const Icon(Icons.flag_rounded,color:AppColors.error,size:28),const SizedBox(width:AppTheme.spaceMD),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Reporting: ${widget.reportedUserName}',style:AppTextStyles.titleSmall.copyWith(color:AppColors.error)),Text('All reports are reviewed within 24 hours.',style:AppTextStyles.bodySmall)]))])),
        const SizedBox(height:AppTheme.spaceXXL),
        Text('Reason for Report',style:AppTextStyles.titleMedium),
        const SizedBox(height:AppTheme.spaceMD),
        ..._reasons.map((r)=>Padding(padding:const EdgeInsets.only(bottom:AppTheme.spaceSM),child:GestureDetector(onTap:()=>setState(()=>_reason=r),child:Container(padding:const EdgeInsets.all(AppTheme.spaceMD),decoration:BoxDecoration(color:_reason==r?AppColors.errorSurface:AppColors.surface,borderRadius:BorderRadius.circular(AppTheme.radiusMD),border:Border.all(color:_reason==r?AppColors.error:AppColors.border,width:_reason==r?2:1)),child:Row(children:[Icon(_reason==r?Icons.radio_button_checked:Icons.radio_button_unchecked,color:_reason==r?AppColors.error:AppColors.grey400,size:20),const SizedBox(width:AppTheme.spaceSM),Text(r,style:AppTextStyles.bodyMedium.copyWith(color:_reason==r?AppColors.error:AppColors.textPrimary))]))))),
        const SizedBox(height:AppTheme.spaceXL),
        AppTextField(controller:_detailsCtrl,label:'Additional Details',hint:'Describe what happened in detail...',maxLines:4),
        const SizedBox(height:AppTheme.space3XL),
        AppButton(label:'Submit Report',leadingIcon:Icons.flag_rounded,type:AppButtonType.danger,onPressed:_submit,isLoading:prov.isSubmitting),
        const SizedBox(height:AppTheme.space3XL),
      ])),
    ));
  }
}