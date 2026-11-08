import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityReportModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNumber; // 호실
  final String? seatNumber; // 자리번호
  final String? building;
  final String? dormBuilding; // 기숙사 건물 (샬롬하우스/국제생활관)
  final String category; // 'maintenance', 'electrical', 'other'
  final String description;
  final List<String>? mediaUrls;
  final DateTime reportedAt;
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime? completedAt;
  final String? technicianNote;
  // 학생이 직접 처리하고 "자체 처리" 버튼으로 완료 표시한 경우 true.
  // 관리자가 처리한 completed와 구분하기 위한 값이다.
  final bool selfResolved;
  final String? selfResolvedNote;

  FacilityReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNumber,
    this.seatNumber,
    this.building,
    this.dormBuilding,
    required this.category,
    required this.description,
    this.mediaUrls,
    required this.reportedAt,
    this.status = 'pending',
    this.completedAt,
    this.technicianNote,
    this.selfResolved = false,
    this.selfResolvedNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'roomNumber': roomNumber,
      'seatNumber': seatNumber,
      'building': building,
      'dormBuilding': dormBuilding,
      'category': category,
      'description': description,
      'mediaUrls': mediaUrls,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'technicianNote': technicianNote,
      'selfResolved': selfResolved,
      'selfResolvedNote': selfResolvedNote,
    };
  }

  factory FacilityReportModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        return null;
      }
    }

    // backward compatibility: old data has single imageUrl
    List<String>? mediaUrls;
    if (map['mediaUrls'] != null) {
      mediaUrls = List<String>.from(map['mediaUrls']);
    } else if (map['imageUrl'] != null) {
      mediaUrls = [map['imageUrl'] as String];
    }

    return FacilityReportModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNumber: map['roomNumber'] ?? '000',
      seatNumber: map['seatNumber'],
      building: map['building'],
      dormBuilding: map['dormBuilding'],
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      mediaUrls: mediaUrls,
      reportedAt: parseDateTime(map['reportedAt']) ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      completedAt: parseDateTime(map['completedAt']),
      technicianNote: map['technicianNote'],
      selfResolved: map['selfResolved'] ?? false,
      selfResolvedNote: map['selfResolvedNote'],
    );
  }
}
