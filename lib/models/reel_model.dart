import 'package:cloud_firestore/cloud_firestore.dart';

class ReelModel {
  final String   reelId;
  // userId / fundiId — both kept; fundiId is the canonical field
  final String   fundiId;
  final String   fundiName;
  final String   fundiProfileImage;
  final String   category;
  final String   caption;
  final String   videoUrl;
  final String   thumbnailUrl;
  /// storagePath holds the Cloudinary publicId (used for server-side deletion)
  final String   storagePath;
  final String   thumbnailPath;
  final DateTime createdAt;
  final int      likesCount;
  final int      viewsCount;
  final int      savesCount;
  final int      reportCount;
  final int      commentsCount;
  /// status: 'pending' | 'approved' | 'rejected'
  final String   status;
  final String   location;
  final double   rating;
  final int      jobsDone;
  final String   rejectionReason;
  final int      durationSeconds;

  // ── Admin review fields ─────────────────────────────────────────────────
  final bool      isActive;
  final DateTime? approvedAt;
  final String    approvedBy;
  final DateTime? rejectedAt;
  final String    rejectedBy;
  // ── Soft-delete fields ──────────────────────────────────────────
  final bool      isDeleted;
  final DateTime? deletedAt;
  final String    deletedBy;  // uid of deleter

  const ReelModel({
    required this.reelId,
    required this.fundiId,
    required this.fundiName,
    required this.fundiProfileImage,
    required this.category,
    required this.caption,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.storagePath        = '',
    this.thumbnailPath      = '',
    required this.createdAt,
    this.likesCount         = 0,
    this.viewsCount         = 0,
    this.savesCount         = 0,
    this.reportCount        = 0,
    this.commentsCount      = 0,
    required this.status,
    required this.location,
    this.rating             = 0.0,
    this.jobsDone           = 0,
    this.rejectionReason    = '',
    this.durationSeconds    = 0,
    this.isActive           = false,
    this.approvedAt,
    this.approvedBy         = '',
    this.rejectedAt,
    this.rejectedBy         = '',
    this.isDeleted          = false,
    this.deletedAt,
    this.deletedBy          = '',
  });

  bool get isApproved => status == 'approved';
  bool get isPending  => status == 'pending';
  bool get isRejected => status == 'rejected';

  // Convenience: reel is visible in the public feed
  bool get isPublic  => isApproved && isActive && !isDeleted;
  bool get isSoftDeleted => isDeleted;

  factory ReelModel.fromMap(Map<String, dynamic> map) {
    DateTime? _ts(dynamic v) =>
        v is Timestamp ? v.toDate() : null;

    return ReelModel(
      reelId:            (map['reelId']            ?? '').toString(),
      fundiId:           (map['fundiId']           ?? map['userId'] ?? '').toString(),
      fundiName:         (map['fundiName']         ?? map['userName'] ?? '').toString(),
      fundiProfileImage: (map['fundiProfileImage'] ?? map['userPhoto'] ?? '').toString(),
      category:          (map['category']          ?? '').toString(),
      caption:           (map['caption']           ?? '').toString(),
      videoUrl:          (map['videoUrl']          ?? '').toString(),
      thumbnailUrl:      (map['thumbnailUrl']      ?? '').toString(),
      storagePath:       (map['storagePath']       ?? map['publicId'] ?? '').toString(),
      thumbnailPath:     (map['thumbnailPath']     ?? '').toString(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      likesCount:     (map['likesCount']    as num?)?.toInt() ?? 0,
      viewsCount:     (map['viewsCount']    as num?)?.toInt() ?? 0,
      savesCount:     (map['savesCount']    as num?)?.toInt() ?? 0,
      reportCount:    (map['reportCount']   as num?)?.toInt() ?? 0,
      commentsCount:  (map['commentsCount'] as num?)?.toInt() ?? 0,
      status:            (map['status']          ?? 'pending').toString(),
      location:          (map['location']         ?? '').toString(),
      rating:        (map['rating']        as num?)?.toDouble() ?? 0.0,
      jobsDone:      (map['jobsDone']      as num?)?.toInt()    ?? 0,
      rejectionReason:   (map['rejectionReason']  ?? '').toString(),
      durationSeconds:   (map['durationSeconds']  as num?)?.toInt() ?? 0,
      isActive:   map['isActive'] == true,
      approvedAt: _ts(map['approvedAt']),
      approvedBy: (map['approvedBy'] ?? '').toString(),
      rejectedAt: _ts(map['rejectedAt']),
      rejectedBy:  (map['rejectedBy']  ?? '').toString(),
      isDeleted:   map['isDeleted']  == true,
      deletedAt:   _ts(map['deletedAt']),
      deletedBy:   (map['deletedBy']   ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'reelId':            reelId,
    'fundiId':           fundiId,
    'userId':            fundiId,      // alias for legacy queries
    'fundiName':         fundiName,
    'userName':          fundiName,    // alias
    'fundiProfileImage': fundiProfileImage,
    'userPhoto':         fundiProfileImage,
    'category':          category,
    'caption':           caption,
    'videoUrl':          videoUrl,
    'thumbnailUrl':      thumbnailUrl,
    'storagePath':       storagePath,
    'publicId':          storagePath,  // alias
    'thumbnailPath':     thumbnailPath,
    'createdAt':         Timestamp.fromDate(createdAt),
    'likesCount':        likesCount,
    'viewsCount':        viewsCount,
    'savesCount':        savesCount,
    'reportCount':       reportCount,
    'status':            status,
    'location':          location,
    'rating':            rating,
    'jobsDone':          jobsDone,
    'rejectionReason':   rejectionReason,
    'durationSeconds':   durationSeconds,
    'isActive':          isActive,
    if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    'approvedBy':        approvedBy,
    if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
    'rejectedBy':        rejectedBy,
    'isDeleted':         isDeleted,
    if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    'deletedBy':         deletedBy,
  };

  ReelModel copyWith({
    int?     likesCount,
    int?     viewsCount,
    int?     savesCount,
    int?     commentsCount,
    String?  status,
    String?  rejectionReason,
    bool?    isActive,
    String?  approvedBy,
    String?  rejectedBy,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    bool?    isDeleted,
    String?  deletedBy,
    DateTime? deletedAt,
  }) => ReelModel(
    reelId:            reelId,
    fundiId:           fundiId,
    fundiName:         fundiName,
    fundiProfileImage: fundiProfileImage,
    category:          category,
    caption:           caption,
    videoUrl:          videoUrl,
    thumbnailUrl:      thumbnailUrl,
    storagePath:       storagePath,
    thumbnailPath:     thumbnailPath,
    createdAt:         createdAt,
    likesCount:        likesCount      ?? this.likesCount,
    viewsCount:        viewsCount      ?? this.viewsCount,
    savesCount:        savesCount      ?? this.savesCount,
    commentsCount:     commentsCount   ?? this.commentsCount,
    reportCount:       reportCount,
    status:            status         ?? this.status,
    location:          location,
    rating:            rating,
    jobsDone:          jobsDone,
    rejectionReason:   rejectionReason ?? this.rejectionReason,
    durationSeconds:   durationSeconds,
    isActive:          isActive       ?? this.isActive,
    approvedAt:        approvedAt     ?? this.approvedAt,
    approvedBy:        approvedBy     ?? this.approvedBy,
    rejectedAt:        rejectedAt     ?? this.rejectedAt,
    rejectedBy:        rejectedBy     ?? this.rejectedBy,
    isDeleted:         isDeleted      ?? this.isDeleted,
    deletedAt:         deletedAt      ?? this.deletedAt,
    deletedBy:         deletedBy      ?? this.deletedBy,
  );
}
