import 'package:cloud_firestore/cloud_firestore.dart';
class ReviewModel {
  final String reviewId,bookingId,clientId,clientName,fundiId,comment;
  final String? clientImageUrl;
  final double rating;
  final DateTime createdAt;
  const ReviewModel({required this.reviewId,required this.bookingId,required this.clientId,required this.clientName,this.clientImageUrl,required this.fundiId,required this.comment,required this.rating,required this.createdAt});
  factory ReviewModel.fromMap(Map<String,dynamic> map) => ReviewModel(reviewId:map['reviewId']??'',bookingId:map['bookingId']??'',clientId:map['clientId']??'',clientName:map['clientName']??'',clientImageUrl:map['clientImageUrl'],fundiId:map['fundiId']??'',comment:map['comment']??'',rating:(map['rating'] as num?)?.toDouble()??0.0,createdAt:map['createdAt'] is Timestamp?(map['createdAt'] as Timestamp).toDate():DateTime.now());
  Map<String,dynamic> toMap() => {'reviewId':reviewId,'bookingId':bookingId,'clientId':clientId,'clientName':clientName,'clientImageUrl':clientImageUrl,'fundiId':fundiId,'comment':comment,'rating':rating,'createdAt':Timestamp.fromDate(createdAt)};
}