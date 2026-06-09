import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class UserModel {
  final String uid;
  final String email;
  final String role;
  final String fullName;
  final String phone;
  final String region;
  final String district;
  final String area;
  final String detectedAddress;
  final String savedLocationPreference;
  final String accountStatus;
  final String bio;
  final String category;
  final String experience;
  final String plan;
  final int jobsDone;
  final int completedJobsCount;
  final double? latitude;
  final double? longitude;
  final String? profileImageUrl;
  final List<String> portfolioImages;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.region,
    required this.district,
    required this.area,
    this.latitude,
    this.longitude,
    required this.detectedAddress,
    required this.savedLocationPreference,
    this.profileImageUrl,
    this.bio = '',
    this.category = '',
    this.experience = '',
    this.plan = AppConstants.planFree,
    this.jobsDone = 0,
    this.completedJobsCount = 0,
    this.portfolioImages = const [],
    required this.accountStatus,
    required this.isProfileComplete,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isClient => role == AppConstants.roleClient;
  bool get isFundi => role == AppConstants.roleFundi;
  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isActive => accountStatus == AppConstants.statusActive;
  bool get isSuspended => accountStatus == AppConstants.statusSuspended;
  bool get isPremium => plan == AppConstants.planPremium;

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: (map['uid'] ?? '').toString(),
        email: (map['email'] ?? '').toString(),
        role: (map['role'] ?? AppConstants.roleClient).toString(),
        fullName: (map['fullName'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
        region: (map['region'] ?? '').toString(),
        district: (map['district'] ?? '').toString(),
        area: (map['area'] ?? '').toString(),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        detectedAddress: (map['detectedAddress'] ?? '').toString(),
        savedLocationPreference:
            (map['savedLocationPreference'] ?? 'manual').toString(),
        profileImageUrl: map['profileImageUrl']?.toString(),
        bio: (map['bio'] ?? '').toString(),
        category: (map['category'] ?? '').toString(),
        experience: (map['experience'] ?? '').toString(),
        plan: (map['plan'] ?? map['subscriptionStatus'] ?? AppConstants.planFree)
            .toString(),
        jobsDone: (map['jobsDone'] as num?)?.toInt() ??
            (map['completedJobsCount'] as num?)?.toInt() ?? 0,
        completedJobsCount: (map['completedJobsCount'] as num?)?.toInt() ??
            (map['jobsDone'] as num?)?.toInt() ?? 0,
        portfolioImages: _stringList(map['portfolioImages']),
        accountStatus:
            (map['accountStatus'] ?? AppConstants.statusActive).toString(),
        isProfileComplete: map['isProfileComplete'] == true,
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: map['updatedAt'] is Timestamp
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'role': role,
        'fullName': fullName,
        'phone': phone,
        'region': region,
        'district': district,
        'area': area,
        'latitude': latitude,
        'longitude': longitude,
        'detectedAddress': detectedAddress,
        'savedLocationPreference': savedLocationPreference,
        'profileImageUrl': profileImageUrl,
        'bio': bio,
        'category': category,
        'experience': experience,
        'plan': plan,
        if (jobsDone > 0) 'jobsDone': jobsDone,
        if (completedJobsCount > 0) 'completedJobsCount': completedJobsCount,
        'portfolioImages': portfolioImages,
        'accountStatus': accountStatus,
        'isProfileComplete': isProfileComplete,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? fullName,
    String? phone,
    String? region,
    String? district,
    String? area,
    double? latitude,
    double? longitude,
    String? detectedAddress,
    String? savedLocationPreference,
    String? profileImageUrl,
    String? bio,
    String? category,
    String? experience,
    String? plan,
    int? jobsDone,
    int? completedJobsCount,
    List<String>? portfolioImages,
    String? accountStatus,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        region: region ?? this.region,
        district: district ?? this.district,
        area: area ?? this.area,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        detectedAddress: detectedAddress ?? this.detectedAddress,
        savedLocationPreference:
            savedLocationPreference ?? this.savedLocationPreference,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        bio: bio ?? this.bio,
        category: category ?? this.category,
        experience: experience ?? this.experience,
        plan: plan ?? this.plan,
        jobsDone: jobsDone ?? this.jobsDone,
        completedJobsCount: completedJobsCount ?? this.completedJobsCount,
        portfolioImages: portfolioImages ?? this.portfolioImages,
        accountStatus: accountStatus ?? this.accountStatus,
        isProfileComplete: isProfileComplete ?? this.isProfileComplete,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
