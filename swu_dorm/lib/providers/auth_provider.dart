import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/term_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _cachedUserKey = 'cached_user_data';

  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSubscription;
  UserModel? _currentUser;
  bool _isLoading = true;
  // 이메일 회원가입 진행 중 플래그.
  // signUpWithEmail은 Auth 계정 생성 → Firestore 문서 생성 순으로 진행되는데,
  // 그 사이 authStateChanges가 먼저 발동하면 users 문서가 아직 없어 상태가 잘못 꼬이는
  // 레이스가 있었다. 가입 진행 중에는 이를 막는다.
  bool _isEmailSignUpInProgress = false;
  // 구글 신규 가입 진행 중 플래그. 위와 동일한 이유로 필요하다.
  bool _isGoogleSignUpInProgress = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initAuth();
  }

  Future<UserModel?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cachedUserKey);
      if (cached != null) {
        return UserModel.fromMap(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveUserToCache(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<void> _clearUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserKey);
    } catch (_) {}
  }

  void _initAuth() {
    _authSubscription = _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          // getUserData가 현재 학기(student_enrollment)를 조회하므로, 그보다 먼저
          // 현재 학기 값이 로드되어 있어야 한다(기본값 'default'로 잘못 조회되는 것 방지).
          await TermService.instance.init();
          final fetched = await _authService.getUserData(user.uid);
          if (fetched != null && fetched.disabled) {
            // 이용 정지된 계정 — 즉시 로그아웃 (가이드라인 1.2, 작성자 퇴출)
            await _authService.signOut();
            _currentUser = null;
            await _clearUserCache();
          } else if (fetched != null) {
            _currentUser = fetched;
            await _saveUserToCache(fetched);
          } else if (_isEmailSignUpInProgress || _isGoogleSignUpInProgress) {
            // 가입이 users 문서를 생성하는 중이므로 아무 상태도 바꾸지 않고
            // signUp 처리가 끝날 때까지 기다린다 (로딩 화면 유지).
          } else {
            // Firestore 문서가 없으면 캐시에서 먼저 복원을 시도한다.
            final cached = await _loadCachedUser();
            if (cached != null) {
              _currentUser = cached;
            } else {
              // 캐시도 없고 알려진 가입 흐름도 아니라면 비정상 상태이므로 로그인 화면으로 되돌린다.
              await _authService.signOut();
              _currentUser = null;
            }
          }
        } catch (_) {
          // 네트워크 오류 등 → 캐시에서 복원
          _currentUser = await _loadCachedUser();
        }
      } else {
        _currentUser = null;
        await _clearUserCache();
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isEmailSignUpInProgress = true;
    try {
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      final uid = credential?.user?.uid;
      if (uid != null) {
        final fetched = await _authService.getUserData(uid);
        if (fetched != null) {
          _currentUser = fetched;
          await _saveUserToCache(fetched);
        }
      }
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    } finally {
      _isEmailSignUpInProgress = false;
      notifyListeners();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      if (credential?.user != null) {
        final userData = await _authService.getUserData(credential!.user!.uid);
        if (userData == null || userData.role != 'student') {
          await _authService.signOut();
          return '학생 계정만 로그인할 수 있습니다.';
        }
        if (userData.disabled) {
          await _authService.signOut();
          return '이 계정은 이용약관 위반으로 이용이 정지되었습니다.\n문의: dormitory@swu.ac.kr';
        }
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> isStudentIdAvailable(String studentId) {
    return _authService.isStudentIdAvailable(studentId);
  }

  // 관리프로그램이 올린 사생 명단에 있는 학번인지 확인한다. true면 가입 가능.
  Future<bool> isStudentIdInRoster(String studentId) {
    return _authService.isStudentIdInRoster(studentId);
  }

  // 반환값: null이면 취소(사용자가 팝업을 닫음) 또는 성공, 문자열이면 에러 메시지.
  // 신규 가입자는 학번 없이 users 문서를 바로 만들어 홈으로 진입한다(학번은 프로필 화면에서 입력).
  Future<String?> signInWithGoogle() async {
    _isGoogleSignUpInProgress = true;
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return null; // 사용자가 취소함

      final uid = result.userCredential.user?.uid;
      if (result.isNewUser) {
        if (uid == null) return '로그인 상태를 확인할 수 없습니다.';
        final newUser = await _authService.createUserDocForGoogle(result.userCredential.user!);
        _currentUser = newUser;
        await _saveUserToCache(newUser);
        return null;
      }

      // 기존 가입자 재로그인 — role 검사(학생 계정만 허용)
      final userData = uid != null ? await _authService.getUserData(uid) : null;
      if (userData == null || userData.role != 'student') {
        await _authService.signOut();
        return '학생 계정만 로그인할 수 있습니다.';
      }
      if (userData.disabled) {
        await _authService.signOut();
        return '이 계정은 이용약관 위반으로 이용이 정지되었습니다.\n문의: dormitory@swu.ac.kr';
      }
      _currentUser = userData;
      await _saveUserToCache(userData);
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    } finally {
      _isGoogleSignUpInProgress = false;
      notifyListeners();
    }
  }

  // 프로필 화면에서 학번을 최초로 입력할 때 호출한다. 이미 등록된 경우에는 호출하지 않는다
  // (화면에서 입력란 자체를 잠가 막는다).
  Future<String?> setStudentId(String studentId) async {
    if (_currentUser == null) return '로그인이 필요합니다.';
    if (_currentUser!.studentId.isNotEmpty) return '이미 학번이 등록되어 있습니다.';
    try {
      await _authService.setStudentId(uid: _currentUser!.uid, studentId: studentId);
      await refreshUserData();
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    await _clearUserCache();
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> refreshUserData() async {
    if (_authService.currentUser != null) {
      _currentUser = await _authService.getUserData(_authService.currentUser!.uid);
      notifyListeners();
    }
  }

  List<String> get blockedUsers => _currentUser?.blockedUsers ?? [];

  Future<String?> blockUser(String targetUid) async {
    if (_currentUser == null) return '로그인이 필요합니다.';
    try {
      await _authService.blockUser(myUid: _currentUser!.uid, targetUid: targetUid);
      await refreshUserData();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> unblockUser(String targetUid) async {
    if (_currentUser == null) return '로그인이 필요합니다.';
    try {
      await _authService.unblockUser(myUid: _currentUser!.uid, targetUid: targetUid);
      await refreshUserData();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  bool get isGoogleSignedIn => _authService.isGoogleSignedIn;

  Future<String?> deleteAccount({String? password}) async {
    try {
      await _authService.deleteAccount(password: password);
      _currentUser = null;
      await _clearUserCache();
      notifyListeners();
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    }
  }
}
