import 'package:cloud_firestore/cloud_firestore.dart';

class BlockModel {
  final String blockId;
  final String blockerId;
  final String blockedId;
  final String blockedName;
  final DateTime createdAt;

  const BlockModel({
    required this.blockId,
    required this.blockerId,
    required this.blockedId,
    required this.blockedName,
    required this.createdAt,
  });

  factory BlockModel.fromMap(Map<String, dynamic> map) => BlockModel(
        blockId: map['blockId'] as String? ?? '',
        blockerId: map['blockerId'] as String? ?? '',
        blockedId: map['blockedId'] as String? ?? '',
        blockedName: map['blockedName'] as String? ?? '',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'blockId': blockId,
        'blockerId': blockerId,
        'blockedId': blockedId,
        'blockedName': blockedName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}