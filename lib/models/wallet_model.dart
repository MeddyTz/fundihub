import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
class WalletModel {
  final String fundiId,feeStatus,lockedReason,subscriptionStatus,promotionStatus;
  final int walletBalance,totalFeesPaid,pendingJobFee;
  final DateTime updatedAt;
  const WalletModel({required this.fundiId,required this.walletBalance,required this.totalFeesPaid,required this.pendingJobFee,required this.feeStatus,required this.lockedReason,required this.subscriptionStatus,required this.promotionStatus,required this.updatedAt});
  bool get isLocked => lockedReason==AppConstants.lockActiveJob||lockedReason==AppConstants.lockJobFeeUnpaid;
  bool get hasPendingFee => feeStatus==AppConstants.feeUnpaid&&pendingJobFee>0;
  bool get isPremium => subscriptionStatus==AppConstants.planPremium;
  factory WalletModel.fromMap(Map<String,dynamic> map) => WalletModel(fundiId:map['fundiId']??'',walletBalance:map['walletBalance']??0,totalFeesPaid:map['totalFeesPaid']??0,pendingJobFee:map['pendingJobFee']??0,feeStatus:map['feeStatus']??AppConstants.feeNone,lockedReason:map['lockedReason']??AppConstants.lockNone,subscriptionStatus:map['subscriptionStatus']??AppConstants.planFree,promotionStatus:map['promotionStatus']??AppConstants.promotionInactive,updatedAt:map['updatedAt'] is Timestamp?(map['updatedAt'] as Timestamp).toDate():DateTime.now());
  Map<String,dynamic> toMap() => {'fundiId':fundiId,'walletBalance':walletBalance,'totalFeesPaid':totalFeesPaid,'pendingJobFee':pendingJobFee,'feeStatus':feeStatus,'lockedReason':lockedReason,'subscriptionStatus':subscriptionStatus,'promotionStatus':promotionStatus,'updatedAt':Timestamp.fromDate(updatedAt)};
  WalletModel copyWith({String? fundiId,int? walletBalance,int? totalFeesPaid,int? pendingJobFee,String? feeStatus,String? lockedReason,String? subscriptionStatus,String? promotionStatus,DateTime? updatedAt}) => WalletModel(fundiId:fundiId??this.fundiId,walletBalance:walletBalance??this.walletBalance,totalFeesPaid:totalFeesPaid??this.totalFeesPaid,pendingJobFee:pendingJobFee??this.pendingJobFee,feeStatus:feeStatus??this.feeStatus,lockedReason:lockedReason??this.lockedReason,subscriptionStatus:subscriptionStatus??this.subscriptionStatus,promotionStatus:promotionStatus??this.promotionStatus,updatedAt:updatedAt??this.updatedAt);
}
