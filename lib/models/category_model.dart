import 'package:cloud_firestore/cloud_firestore.dart';
class CategoryModel {
  final String id,name,iconName;
  final bool isActive;
  final int fundiCount;
  final DateTime createdAt;
  const CategoryModel({required this.id,required this.name,required this.iconName,required this.isActive,required this.fundiCount,required this.createdAt});
  factory CategoryModel.fromMap(Map<String,dynamic> map,String docId) => CategoryModel(id:docId,name:map['name']??'',iconName:map['iconName']??'handyman',isActive:map['isActive']??true,fundiCount:map['fundiCount']??0,createdAt:map['createdAt'] is Timestamp?(map['createdAt'] as Timestamp).toDate():DateTime.now());
  Map<String,dynamic> toMap() => {'name':name,'iconName':iconName,'isActive':isActive,'fundiCount':fundiCount,'createdAt':Timestamp.fromDate(createdAt)};
}
class OtherCategoryRequest {
  final String requestId,fundiId,fundiName,phone,region,district,otherCategoryName,status;
  final DateTime submittedAt;
  const OtherCategoryRequest({required this.requestId,required this.fundiId,required this.fundiName,required this.phone,required this.region,required this.district,required this.otherCategoryName,required this.submittedAt,required this.status});
  factory OtherCategoryRequest.fromMap(Map<String,dynamic> map) => OtherCategoryRequest(requestId:map['requestId']??'',fundiId:map['fundiId']??'',fundiName:map['fundiName']??'',phone:map['phone']??'',region:map['region']??'',district:map['district']??'',otherCategoryName:map['otherCategoryName']??'',submittedAt:map['submittedAt'] is Timestamp?(map['submittedAt'] as Timestamp).toDate():DateTime.now(),status:map['status']??'pending');
  Map<String,dynamic> toMap() => {'requestId':requestId,'fundiId':fundiId,'fundiName':fundiName,'phone':phone,'region':region,'district':district,'otherCategoryName':otherCategoryName,'submittedAt':Timestamp.fromDate(submittedAt),'status':status};
}
