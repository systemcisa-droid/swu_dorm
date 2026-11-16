import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 학기별로 나뉘는 운영 데이터(/terms/{termId}/...)의 경로를 다루는 헬퍼.
///
/// 계정 신원(student/admin), 게시판류(posts 등)는 학기 무관 전역 컬렉션이라
/// 이 서비스를 거치지 않고 기존처럼 바로 FirebaseFirestore.instance.collection(...)을 쓴다.
///
/// 앱이 로그인 상태로 전환될 때 [init]을 한 번 await 한 뒤에만 [term]을 호출해야 한다.
/// 초기화 전에 호출하면 'default' 학기로 처리된다.
///
/// ── 조회 전용 학기(관리프로그램 전용) ──
/// [viewOverride]를 설정하면 이 프로그램 인스턴스에서만 [term]이 그 학기를 가리키게
/// 된다 — settings/current_term(전체 시스템이 보는 "현재 학기")은 바뀌지 않으므로
/// 학생앱·층장앱 등 다른 앱에는 전혀 영향이 없다. 과거 학기 자료를 잠깐 들여다볼 때
/// 쓰고, 다 보면 [clearViewOverride]로 다시 현재 학기로 돌아가야 한다.
class TermService {
  TermService._();
  static final TermService instance = TermService._();

  static const String fallbackTermId = 'default';

  String _termId = fallbackTermId;
  String get currentTermId => _termId;

  /// null이면 현재(라이브) 학기를 그대로 쓴다는 뜻.
  final ValueNotifier<String?> viewOverride = ValueNotifier<String?>(null);

  bool get isViewingOverride => viewOverride.value != null;

  void setViewOverride(String termId) => viewOverride.value = termId;
  void clearViewOverride() => viewOverride.value = null;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 인증 상태가 바뀔 때마다 앱 진입점에서 init()을 다시 불러도(Consumer/StreamBuilder
  // 재빌드 등) 구독이 중복 생성되지 않도록 한 세션에 한 번만 실제로 수행한다.
  Future<void>? _initFuture;

  /// 관리프로그램 설정에서 학기를 바꾸면 이 스트림을 통해 실시간으로 반영된다.
  /// (단, 이미 생성되어 쓰이고 있는 CollectionReference 자체는 바뀌지 않으므로
  /// 학기 전환은 앱을 다시 시작해야 완전히 반영된다.)
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      final doc = await _firestore.collection('settings').doc('current_term').get();
      final termId = doc.data()?['termId'] as String?;
      if (termId != null && termId.isNotEmpty) _termId = termId;
    } catch (_) {
      // 권한 오류 등으로 못 읽으면 fallback 학기로 둔다.
    }
    _firestore
        .collection('settings')
        .doc('current_term')
        .snapshots()
        .listen((snap) {
      final termId = snap.data()?['termId'] as String?;
      if (termId != null && termId.isNotEmpty) _termId = termId;
    });
  }

  /// 학기별로 분리된 컬렉션 참조. 예: TermService.instance.term('meals')
  /// [viewOverride]가 설정되어 있으면(과거 학기 조회 중) 그 학기를 가리킨다.
  CollectionReference<Map<String, dynamic>> term(String collectionName) {
    final effectiveTermId = viewOverride.value ?? _termId;
    return _firestore.collection('terms').doc(effectiveTermId).collection(collectionName);
  }
}
