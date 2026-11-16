import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityReportModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNumber;
  final String? seatNumber; // 자리번호
  final String? building;
  final String category; // 'maintenance', 'plumbing', 'electrical', 'common_area', 'other'
  final String description;
  final List<String>? mediaUrls;
  final DateTime reportedAt;
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime? completedAt;
  final String? technicianNote;
  final String? processedBy; // 처리한 관리자 ID
  final String? processedByName; // 처리한 관리자 이름
  final DateTime? processedAt; // 처리 일시
  // 학생이 학생앱에서 "자체 처리" 버튼으로 직접 완료 표시한 경우 true.
  // 이때 status는 'completed'로 저장되지만 관리자가 처리한 것과 구분해 보여준다.
  final bool selfResolved;
  final String? selfResolvedNote;

  FacilityReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNumber,
    this.seatNumber,
    this.building,
    required this.category,
    required this.description,
    this.mediaUrls,
    required this.reportedAt,
    this.status = 'pending',
    this.completedAt,
    this.technicianNote,
    this.processedBy,
    this.processedByName,
    this.processedAt,
    this.selfResolved = false,
    this.selfResolvedNote,
  });

  factory FacilityReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // backward compatibility: old data has single imageUrl
    List<String>? mediaUrls;
    if (data['mediaUrls'] != null) {
      mediaUrls = List<String>.from(data['mediaUrls']);
    } else if (data['imageUrl'] != null) {
      mediaUrls = [data['imageUrl'] as String];
    }

    return FacilityReportModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      roomNumber: data['roomNumber'] ?? '000',
      seatNumber: data['seatNumber'],
      building: data['building'],
      category: data['category'] ?? 'other',
      description: data['description'] ?? '',
      mediaUrls: mediaUrls,
      reportedAt: parseDateTime(data['reportedAt']) ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      completedAt: parseDateTime(data['completedAt']),
      technicianNote: data['technicianNote'],
      processedBy: data['processedBy'],
      processedByName: data['processedByName'],
      processedAt: parseDateTime(data['processedAt']),
      selfResolved: data['selfResolved'] ?? false,
      selfResolvedNote: data['selfResolvedNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNumber': roomNumber,
      'seatNumber': seatNumber,
      'building': building,
      'category': category,
      'description': description,
      'mediaUrls': mediaUrls,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'technicianNote': technicianNote,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'selfResolved': selfResolved,
      'selfResolvedNote': selfResolvedNote,
    };
  }

  String getCategoryDisplayName() {
    switch (category) {
      case 'maintenance':
        return '가구/도어';
      case 'plumbing':
        return '수도/냉난방';
      case 'electrical':
        return '전기';
      case 'common_area':
        return '공동구역(헬스장, 기도실 등)';
      case 'other':
        return '기타';
      default:
        return category;
    }
  }

  String getStatusDisplayName() {
    if (status == 'completed' && selfResolved) return '자체 처리';
    switch (status) {
      case 'pending':
        return '대기중';
      case 'in_progress':
        return '처리중';
      case 'completed':
        return '완료됨';
      default:
        return status;
    }
  }
}
