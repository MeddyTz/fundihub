import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class FundiModel {
  final String uid;
  final String email;
  final String role;
  final String fullName;
  final String phone;
  final String category;
  final String experience;
  final String bio;
  final String region;
  final String district;
  final String area;
  final String detectedAddress;
  final String plan;
  final String promotionStatus;
  final String accountStatus;

  final String? otherCategoryName;
  final String? profileImageUrl;

  final bool boostActive;
  final DateTime? boostExpiresAt;

  final List<String> skills;
  final List<String> portfolioImages;

  final double? latitude;
  final double? longitude;

  final double rating;
  final int reviewCount;
  final int jobsDone;

  final bool isProfileComplete;

  final DateTime? locationUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FundiModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.category,
    this.otherCategoryName,
    required this.skills,
    this.portfolioImages = const [],
    required this.experience,
    required this.bio,
    required this.region,
    required this.district,
    required this.area,
    this.latitude,
    this.longitude,
    required this.detectedAddress,
    this.profileImageUrl,
    this.boostActive = false,
    this.boostExpiresAt,
    required this.rating,
    required this.reviewCount,
    required this.jobsDone,
    required this.plan,
    required this.promotionStatus,
    required this.accountStatus,
    required this.isProfileComplete,
    this.locationUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFree => plan == AppConstants.planFree;
  bool get isPremium => plan == AppConstants.planPremium;
  bool get isPromoted {
    final statusActive = promotionStatus == AppConstants.promotionActive || boostActive;
    if (!statusActive) return false;
    if (boostExpiresAt == null) return true;
    return boostExpiresAt!.isAfter(DateTime.now());
  }
  bool get isActive => accountStatus == AppConstants.statusActive;
  bool get isSuspended => accountStatus == AppConstants.statusSuspended;
  bool get isOtherCategory => category == AppConstants.categoryOthers;

  String get displayCategory =>
      isOtherCategory && otherCategoryName != null && otherCategoryName!.trim().isNotEmpty
          ? otherCategoryName!
          : category;

  factory FundiModel.fromMap(Map<String, dynamic> map) {
    return FundiModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? AppConstants.roleFundi,
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      category: map['category'] ?? '',
      otherCategoryName: map['otherCategoryName'],
      skills: List<String>.from(map['skills'] ?? []),
      portfolioImages: List<String>.from(map['portfolioImages'] ?? const []),
      experience: map['experience'] ?? '',
      bio: map['bio'] ?? '',
      region: map['region'] ?? '',
      district: map['district'] ?? '',
      area: map['area'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      detectedAddress: map['detectedAddress'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      boostActive: map['boostActive'] == true,
      boostExpiresAt: _dateFromAny(map['boostExpiresAt'] ?? map['promotionExpiresAt']),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      jobsDone: (map['jobsDone'] as num?)?.toInt() ?? 0,
      plan: map['plan'] ?? AppConstants.planFree,
      promotionStatus: map['promotionStatus'] ?? AppConstants.promotionInactive,
      accountStatus: map['accountStatus'] ?? AppConstants.statusActive,
      isProfileComplete: map['isProfileComplete'] ?? false,
      locationUpdatedAt: map['locationUpdatedAt'] is Timestamp
          ? (map['locationUpdatedAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }


  static DateTime? _dateFromAny(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'fullName': fullName,
      'phone': phone,
      'category': category,
      'otherCategoryName': otherCategoryName,
      'skills': skills,
      'portfolioImages': portfolioImages,
      'experience': experience,
      'bio': bio,
      'region': region,
      'district': district,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'detectedAddress': detectedAddress,
      'profileImageUrl': profileImageUrl,
      'boostActive': boostActive,
      'boostExpiresAt': boostExpiresAt != null ? Timestamp.fromDate(boostExpiresAt!) : null,
      'promotionExpiresAt': boostExpiresAt != null ? Timestamp.fromDate(boostExpiresAt!) : null,
      'rating': rating,
      'reviewCount': reviewCount,
      'jobsDone': jobsDone,
      'plan': plan,
      'promotionStatus': promotionStatus,
      'accountStatus': accountStatus,
      'isProfileComplete': isProfileComplete,
      'locationUpdatedAt':
          locationUpdatedAt != null ? Timestamp.fromDate(locationUpdatedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}