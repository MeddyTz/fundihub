import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String   commentId;
  final String   reelId;
  final String   userId;
  final String   userName;
  final String   userPhoto;
  final String    text;
  final DateTime  createdAt;
  final bool      isEdited;
  final DateTime? editedAt;

  const CommentModel({
    required this.commentId,
    required this.reelId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.text,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) => CommentModel(
        commentId: (map['commentId'] ?? map['id'] ?? '').toString(),
        reelId:    (map['reelId']    ?? '').toString(),
        userId:    (map['userId']    ?? '').toString(),
        userName:  (map['userName']  ?? 'User').toString(),
        userPhoto: (map['userPhoto'] ?? '').toString(),
        text:      (map['text']      ?? '').toString(),
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        isEdited: map['isEdited'] == true,
        editedAt: map['editedAt'] is Timestamp
            ? (map['editedAt'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'commentId': commentId,
        'reelId':    reelId,
        'userId':    userId,
        'userName':  userName,
        'userPhoto': userPhoto,
        'text':      text,
        'createdAt': Timestamp.fromDate(createdAt),
        'isEdited':  isEdited,
        if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      };

  CommentModel copyWith({String? text, bool? isEdited, DateTime? editedAt}) =>
      CommentModel(
        commentId: commentId,
        reelId:    reelId,
        userId:    userId,
        userName:  userName,
        userPhoto: userPhoto,
        text:      text     ?? this.text,
        createdAt: createdAt,
        isEdited:  isEdited ?? this.isEdited,
        editedAt:  editedAt ?? this.editedAt,
      );
}
