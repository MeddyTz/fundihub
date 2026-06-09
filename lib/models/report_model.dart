import 'package:cloud_firestore/cloud_firestore.dart';
class ReportModel {
  final String reportId,reporterId,reporterName,reportedUserId,reportedUserName,reason,details,status;
  final String? relatedBookingId;
  final DateTime createdAt;
  const ReportModel({required this.reportId,required this.reporterId,required this.reporterName,required this.reportedUserId,required this.reportedUserName,required this.reason,required this.details,required this.status,this.relatedBookingId,required this.createdAt});
  factory ReportModel.fromMap(Map<String,dynamic> map) => ReportModel(reportId:map['reportId']??'',reporterId:map['reporterId']??'',reporterName:map['reporterName']??'',reportedUserId:map['reportedUserId']??'',reportedUserName:map['reportedUserName']??'',reason:map['reason']??'',details:map['details']??'',status:map['status']??'pending',relatedBookingId:map['relatedBookingId'],createdAt:map['createdAt'] is Timestamp?(map['createdAt'] as Timestamp).toDate():DateTime.now());
  Map<String,dynamic> toMap() => {'reportId':reportId,'reporterId':reporterId,'reporterName':reporterName,'reportedUserId':reportedUserId,'reportedUserName':reportedUserName,'reason':reason,'details':details,'status':status,'relatedBookingId':relatedBookingId,'createdAt':Timestamp.fromDate(createdAt)};
}