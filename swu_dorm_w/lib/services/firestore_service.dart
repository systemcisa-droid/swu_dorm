import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swu_dormi_admin/services/term_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 컬렉션 참조 가져오기
  CollectionReference get notices => _firestore.collection('notices');
  CollectionReference get checkInOutRequests => TermService.instance.term('check_in_out_requests');
  CollectionReference get overnightRequests => TermService.instance.term('overnight_requests');
  CollectionReference get facilities => _firestore.collection('facilities');
  CollectionReference get meals => TermService.instance.term('meals');
  CollectionReference<Map<String, dynamic>> get students => _firestore.collection('student');
  CollectionReference<Map<String, dynamic>> get admins => _firestore.collection('admin');

  /// users 컬렉션이 student/admin으로 분리되면서, uid만으로는 어느 쪽인지
  /// 알 수 없는 화면(학생·관리자가 섞여 보이는 메시지/알림/신고 등)에서 쓰는 조회 헬퍼.
  /// student를 먼저 찾고 없으면 admin을 찾는다. student인 경우 현재 학기의
  /// student_enrollment(방/건물/자리)도 함께 합쳐서 반환한다.
  static Future<Map<String, dynamic>?> fetchProfileByUid(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final studentDoc = await firestore.collection('student').doc(uid).get();
    if (studentDoc.exists) {
      final enrollmentDoc =
          await TermService.instance.term('student_enrollment').doc(uid).get();
      return {
        ...?studentDoc.data(),
        ...?enrollmentDoc.data(),
      };
    }
    final adminDoc = await firestore.collection('admin').doc(uid).get();
    return adminDoc.data();
  }
  CollectionReference get chats => _firestore.collection('chats');

  // 공지사항 관리
  Future<void> addNotice(Map<String, dynamic> noticeData) async {
    try {
      await notices.add({
        ...noticeData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('공지사항 추가 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> updateNotice(String noticeId, Map<String, dynamic> noticeData) async {
    try {
      await notices.doc(noticeId).update({
        ...noticeData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('공지사항 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteNotice(String noticeId) async {
    try {
      await notices.doc(noticeId).delete();
    } catch (e) {
      throw Exception('공지사항 삭제 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getNotices() {
    return notices.orderBy('createdAt', descending: true).snapshots();
  }

  // 입퇴사 신청 관리
  Future<void> updateCheckInOutStatus(
    String requestId,
    String status,
    String? reason,
    {String? approvedTime}
  ) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 입퇴사 처리 시작 =====');
      print('현재 로그인 사용자 UID: ${currentUser?.uid}');
      print('현재 로그인 사용자 Email: ${currentUser?.email}');

      String? adminName;

      if (currentUser != null) {
        // 관리자 이름 가져오기
        print('관리자 정보 조회 중...');
        final adminDoc = await admins.doc(currentUser.uid).get();
        print('관리자 문서 존재 여부: ${adminDoc.exists}');

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminName = adminData['name'] ?? adminData['email'];
          print('조회된 관리자 이름: $adminName');
          print('관리자 전체 데이터: $adminData');
        } else {
          print('⚠️ 관리자 문서를 찾을 수 없음!');
        }
      } else {
        print('⚠️ 현재 로그인한 사용자가 없음!');
      }

      final Map<String, dynamic> updateData = {
        'status': status,
        'rejectionReason': reason,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser?.uid,
        'processedByName': adminName ?? '관리자',
      };

      print('저장할 데이터: $updateData');
      print('===== 입퇴사 처리 완료 =====');

      // 승인 시 승인 시간 추가
      if (status == 'approved' && approvedTime != null) {
        updateData['approvedTime'] = approvedTime;
      }

      await checkInOutRequests.doc(requestId).update(updateData);
    } catch (e) {
      throw Exception('입퇴사 신청 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getCheckInOutRequests({String? status}) {
    Query query = checkInOutRequests;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  // 외박 신청 관리
  Future<void> updateOvernightStatus(String requestId, String status, String? reason) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 외박 처리 시작 =====');
      print('현재 로그인 사용자 UID: ${currentUser?.uid}');
      print('현재 로그인 사용자 Email: ${currentUser?.email}');

      String? adminName;

      if (currentUser != null) {
        // 관리자 이름 가져오기
        print('관리자 정보 조회 중...');
        final adminDoc = await admins.doc(currentUser.uid).get();
        print('관리자 문서 존재 여부: ${adminDoc.exists}');

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminName = adminData['name'] ?? adminData['email'];
          print('조회된 관리자 이름: $adminName');
        } else {
          print('⚠️ 관리자 문서를 찾을 수 없음!');
        }
      } else {
        print('⚠️ 현재 로그인한 사용자가 없음!');
      }

      final updateData = {
        'status': status,
        'rejectionReason': reason,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser?.uid,
        'processedByName': adminName ?? '관리자',
      };

      print('저장할 데이터: $updateData');
      await overnightRequests.doc(requestId).update(updateData);
      print('===== 외박 처리 완료 =====');
    } catch (e) {
      throw Exception('외박 신청 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getOvernightRequests({String? status}) {
    Query query = overnightRequests;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  // 시설 신고 관리
  Future<void> updateFacilityStatus(String facilityId, String status, String? note) async {
    try {
      await facilities.doc(facilityId).update({
        'status': status,
        'adminNote': note,
        'processedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('시설 신고 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getFacilities({String? status}) {
    Query query = facilities;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  // 시설 신고
  Stream<QuerySnapshot> getFacilityReports({String? status}) {
    Query query = TermService.instance.term('facility_reports');
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  Future<void> updateFacilityReportStatus(
    String reportId,
    String status,
    String? technicianNote, {
    String? category,
    bool selfResolved = false,
  }) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 시설 신고 처리 시작 (facility_reports) =====');
      print('현재 로그인 사용자 UID: ${currentUser?.uid}');
      print('현재 로그인 사용자 Email: ${currentUser?.email}');

      String? adminEmail = currentUser?.email;

      if (currentUser != null) {
        // 관리자 이메일 가져오기
        print('관리자 정보 조회 중...');
        final adminDoc = await admins.doc(currentUser.uid).get();
        print('관리자 문서 존재 여부: ${adminDoc.exists}');

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminEmail = adminData['email'] ?? currentUser.email;
          print('조회된 관리자 이메일: $adminEmail');
        } else {
          print('⚠️ 관리자 문서를 찾을 수 없음!');
        }
      } else {
        print('⚠️ 현재 로그인한 사용자가 없음!');
      }

      final data = <String, dynamic>{
        'status': status,
        'technicianNote': technicianNote,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser?.uid,
        'processedByName': adminEmail ?? '관리자',
        // 관리자가 직접 "자체 처리"를 고르지 않는 한, 상태를 바꾸면 기존
        // 학생의 "자체 처리" 표시는 해제한다.
        'selfResolved': selfResolved,
        if (!selfResolved) 'selfResolvedNote': null,
      };

      // 관리자가 신고 분류를 정정한 경우에만 반영한다.
      if (category != null) {
        data['category'] = category;
      }

      if (status == 'completed') {
        data['completedAt'] = FieldValue.serverTimestamp();
      }

      print('저장할 데이터: $data');
      await TermService.instance.term('facility_reports').doc(reportId).update(data);
      print('===== 시설 신고 처리 완료 =====');
    } catch (e) {
      throw Exception('시설 신고 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  // 식단표 관리
  /// 생성된 식단표 문서 ID를 반환한다(알림에 대상 식단표를 담기 위함).
  Future<String> addMeal(Map<String, dynamic> mealData) async {
    try {
      final ref = await meals.add({
        ...mealData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      throw Exception('식단표 추가 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> updateMeal(String mealId, Map<String, dynamic> mealData) async {
    try {
      await meals.doc(mealId).update({
        ...mealData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('식단표 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteMeal(String mealId) async {
    try {
      await meals.doc(mealId).delete();
    } catch (e) {
      throw Exception('식단표 삭제 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getMeals() {
    return meals.orderBy('createdAt', descending: true).snapshots();
  }

  // 학생 관리 (orderBy 없이 조회 후 클라이언트 정렬 — 복합 인덱스 불필요)
  Future<QuerySnapshot<Map<String, dynamic>>> getStudentsOnce() {
    return students.where('role', isEqualTo: 'student').get();
  }

  // 현재 학기의 학생 방/호실/자리 배정 전체 (학생 목록과 uid로 합쳐 쓴다)
  Future<QuerySnapshot<Map<String, dynamic>>> getStudentEnrollmentsOnce() {
    return TermService.instance.term('student_enrollment').get();
  }

  // 학기별로 분리된(학생 엔롤먼트) 필드 — student 문서가 아니라
  // terms/{termId}/student_enrollment 에 저장한다.
  static const _enrollmentKeys = {'roomNumber', 'dormBuilding', 'seatNumber', 'building', 'floor'};

  Future<void> updateStudent(String userId, Map<String, dynamic> userData) async {
    try {
      final identityData = Map<String, dynamic>.from(userData)
        ..removeWhere((key, _) => _enrollmentKeys.contains(key));
      final enrollmentData = Map<String, dynamic>.from(userData)
        ..removeWhere((key, _) => !_enrollmentKeys.contains(key));

      // roomNumber가 변경되면 building, floor 계산 필드도 함께 업데이트
      if (enrollmentData.containsKey('roomNumber')) {
        final roomNumber = enrollmentData['roomNumber'] as String;
        final roomNum = int.tryParse(roomNumber);
        if (roomNum != null && roomNumber != '000') {
          final lastTwo = roomNum % 100;
          final floor = roomNum ~/ 100;
          enrollmentData['building'] = (lastTwo >= 1 && lastTwo <= 20)
              ? 'A동'
              : (lastTwo >= 21 && lastTwo <= 35)
                  ? 'B동'
                  : '미배정';
          enrollmentData['floor'] = (floor >= 1 && floor <= 7) ? '${floor}층' : '미배정';
        } else {
          enrollmentData['building'] = '미배정';
          enrollmentData['floor'] = '미배정';
        }
      }

      if (identityData.isNotEmpty) {
        await students.doc(userId).update(identityData);
      }
      if (enrollmentData.isNotEmpty) {
        await TermService.instance
            .term('student_enrollment')
            .doc(userId)
            .set(enrollmentData, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('학생 정보 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteStudent(String userId) async {
    try {
      final userDoc = await students.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final studentId = userData?['studentId'] as String?;

      final batch = FirebaseFirestore.instance.batch();
      batch.delete(students.doc(userId));
      batch.delete(TermService.instance.term('student_enrollment').doc(userId));
      if (studentId != null && studentId.isNotEmpty) {
        batch.delete(FirebaseFirestore.instance.collection('student_ids').doc(studentId));
      }
      await batch.commit();
    } catch (e) {
      throw Exception('회원탈퇴 처리 중 오류가 발생했습니다: $e');
    }
  }

  // 통계 (실시간) - 3초마다 Firestore에서 최신 데이터 가져오기
  Stream<Map<String, int>> getStatisticsStream() async* {
    // 초기 데이터 즉시 제공
    try {
      yield await getStatistics();
    } catch (e) {
      yield {
        'pendingCheckInOut': 0,
        'pendingOvernight': 0,
        'pendingFacilities': 0,
        'totalStudents': 0,
      };
    }

    // 3초마다 업데이트
    await for (var _ in Stream.periodic(const Duration(seconds: 3))) {
      try {
        final stats = await getStatistics();
        yield stats;
      } catch (e) {
        // 에러가 발생해도 이전 데이터 유지 (yield 안 함)
      }
    }
  }

  Future<Map<String, int>> getStatistics() async {
    int checkInOutCount = 0;
    int overnightCount = 0;
    int facilitiesCount = 0;
    int cleaningCount = 0;
    int studentsCount = 0;

    // 각 쿼리를 개별적으로 try-catch 처리
    try {
      final pendingCheckInOut = await checkInOutRequests
          .where('status', isEqualTo: 'pending')
          .get();
      checkInOutCount = pendingCheckInOut.docs.length;
      print('입퇴사 대기: $checkInOutCount');
    } catch (e) {
      print('입퇴사 대기 조회 오류: $e');
    }

    try {
      final pendingOvernight = await overnightRequests
          .where('status', isEqualTo: 'pending')
          .get();
      overnightCount = pendingOvernight.docs.length;
      print('외박 대기: $overnightCount');
      for (var doc in pendingOvernight.docs) {
        print('외박 문서 ID: ${doc.id}');
      }
    } catch (e) {
      print('외박 대기 조회 오류: $e');
    }

    try {
      // facility_reports 컬렉션에서 pending 상태 조회
      final pendingRepairReports = await TermService.instance.term('facility_reports')
          .where('status', isEqualTo: 'pending')
          .get();
      facilitiesCount = pendingRepairReports.docs.length;
      print('시설 신고 (facility_reports): $facilitiesCount');
    } catch (e) {
      print('시설 신고 조회 오류: $e');
    }

    int inProgressFacilities = 0;
    int completedFacilities = 0;
    try {
      final inProgressRepairReports = await TermService.instance.term('facility_reports')
          .where('status', isEqualTo: 'in_progress')
          .get();
      inProgressFacilities = inProgressRepairReports.docs.length;

      final completedRepairReports = await TermService.instance.term('facility_reports')
          .where('status', isEqualTo: 'completed')
          .get();
      completedFacilities = completedRepairReports.docs.length;
    } catch (e) {
      print('시설 신고 상태별 조회 오류: $e');
    }

    try {
      // cleaning_requests 컬렉션에서 pending 상태 조회
      final pendingCleaningRequests = await TermService.instance.term('cleaning_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      cleaningCount = pendingCleaningRequests.docs.length;
      print('청소점검 (cleaning_requests): $cleaningCount');
    } catch (e) {
      print('청소점검 조회 오류: $e');
    }

    int inProgressCleaning = 0;
    int completedCleaning = 0;
    try {
      final inProgressCleaningRequests = await TermService.instance.term('cleaning_requests')
          .where('status', isEqualTo: 'in_progress')
          .get();
      inProgressCleaning = inProgressCleaningRequests.docs.length;

      final completedCleaningRequests = await TermService.instance.term('cleaning_requests')
          .where('status', isEqualTo: 'completed')
          .get();
      completedCleaning = completedCleaningRequests.docs.length;
    } catch (e) {
      print('청소점검 상태별 조회 오류: $e');
    }

    try {
      final totalStudents = await students
          .where('role', isEqualTo: 'student')
          .get();
      studentsCount = totalStudents.docs.length;
      print('총 학생 수: $studentsCount');
    } catch (e) {
      print('총 학생 수 조회 오류: $e');
    }

    final stats = {
      'pendingCheckInOut': checkInOutCount,
      'pendingOvernight': overnightCount,
      'pendingFacilities': facilitiesCount,
      'inProgressFacilities': inProgressFacilities,
      'completedFacilities': completedFacilities,
      'pendingCleaning': cleaningCount,
      'inProgressCleaning': inProgressCleaning,
      'completedCleaning': completedCleaning,
      'totalStudents': studentsCount,
    };
    print('통계 결과: $stats');

    return stats;
  }

  // 알림 전송
  Future<void> sendNotification({
    required List<String> userIds,
    required String type,
    required String title,
    required String content,
    String? targetLabel,
    List<Map<String, String>>? recipients,
  }) async {
    try {
      print('===== 알림 전송 시작 =====');
      print('수신자 수: ${userIds.length}');
      print('제목: $title');

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (final userId in userIds) {
        // user_notifications 컬렉션에 알림 추가 (학생앱과 동일한 구조)
        final notificationRef = TermService.instance.term('user_notifications')
            .doc();

        batch.set(notificationRef, {
          'userId': userId,
          'type': type,
          'title': title,
          'content': content,
          'createdAt': now,
          'isRead': false,
        });
      }

      // 보낸 메시지 이력 저장
      if (type == 'message' || type == 'admin_message') {
        final sentRef = TermService.instance.term('admin_sent_messages').doc();
        batch.set(sentRef, {
          'title': title,
          'content': content,
          'recipientCount': userIds.length,
          'targetLabel': targetLabel ?? '개별 선택',
          'sentAt': now,
          if (recipients != null) 'recipients': recipients,
        });
      }

      await batch.commit();

      // 기기 푸시 알림 요청 (Cloud Function 이 읽어 FCM 으로 발송한다)
      if (userIds.isNotEmpty) {
        await TermService.instance.term('notification_requests').add({
          'type': type,
          'title': title,
          'body': content,
          'userIds': userIds,
          'target': 'users',
          'data': {'type': type},
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      print('===== 알림 전송 완료 =====');
    } catch (e) {
      print('===== 알림 전송 오류 =====');
      print('오류 상세: $e');
      throw Exception('알림 전송 중 오류가 발생했습니다: $e');
    }
  }

  // 보낸 메시지 목록 조회
  Stream<QuerySnapshot> getSentMessages() {
    return TermService.instance.term('admin_sent_messages')
        .orderBy('sentAt', descending: true)
        .snapshots();
  }
}
