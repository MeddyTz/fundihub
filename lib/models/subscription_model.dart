import 'package:cloud_firestore/cloud_firestore.dart';
class SubscriptionModel {
  final String subscriptionId,fundiId,fundiName,paymentId;
  final DateTime startDate,endDate,createdAt;
  final bool isActive;
  final int amountPaid;
  const SubscriptionModel({required this.subscriptionId,required this.fundiId,required this.fundiName,required this.paymentId,required this.startDate,required this.endDate,required this.isActive,required this.amountPaid,required this.createdAt});
  bool get isExpired => endDate.isBefore(DateTime.now());
  int get daysRemaining { final d=endDate.difference(DateTime.now()).inDays; return d<0?0:d; }
  factory SubscriptionModel.fromMap(Map<String,dynamic> map) => SubscriptionModel(subscriptionId:map['subscriptionId']??'',fundiId:map['fundiId']??'',fundiName:map['fundiName']??'',paymentId:map['paymentId']??'',startDate:map['startDate'] is Timestamp?(map['startDate'] as Timestamp).toDate():DateTime.now(),endDate:map['endDate'] is Timestamp?(map['endDate'] as Timestamp).toDate():DateTime.now(),isActive:map['isActive']??false,amountPaid:map['amountPaid']??0,createdAt:map['createdAt'] is Timestamp?(map['createdAt'] as Timestamp).toDate():DateTime.now());
  Map<String,dynamic> toMap() => {'subscriptionId':subscriptionId,'fundiId':fundiId,'fundiName':fundiName,'paymentId':paymentId,'startDate':Timestamp.fromDate(startDate),'endDate':Timestamp.fromDate(endDate),'isActive':isActive,'amountPaid':amountPaid,'createdAt':Timestamp.fromDate(createdAt)};
}