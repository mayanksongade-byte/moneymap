import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

enum AuthStatus { initial, authenticated, unverified, unauthenticated, guest }

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;
  AuthStatus _status = AuthStatus.initial;
  StreamSubscription<User?>? _authSubscription;
  bool _onboardingComplete = false;
  bool _isSettingsLoaded = false;
  String? _cachedUid;
  String? _cachedDisplayName;

  User? get user => _user;
  String? get userId => _user?.uid ?? _cachedUid;
  String? get cachedDisplayName => _cachedDisplayName;
  bool get isLoading => _isLoading;
  bool get isGoogleLoading => _isGoogleLoading;
  String? get error => _error;
  AuthStatus get status => _status;
  bool get isGuest => _status == AuthStatus.guest;
  bool get onboardingComplete => _onboardingComplete;
  bool get isInitialized => _isSettingsLoaded;

  AppAuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load onboarding status, cached UID and Name
    await _loadOnboardingStatus();
    final prefs = await SharedPreferences.getInstance();
    _cachedUid = prefs.getString('last_known_uid');
    _cachedDisplayName = prefs.getString('last_known_name');
    final lastStatus = prefs.getString('last_known_status');
    
    if (_cachedUid != null && lastStatus != null) {
      if (kDebugMode) print('DEBUG-INIT: Found cached user session: $_cachedUid');
      // OPTIMISTIC: Start with cached status to avoid "initial" state blocking redirection
      _status = lastStatus == 'guest' ? AuthStatus.guest : AuthStatus.authenticated;
    }

    // 2. Reduce initial delay
    await Future.delayed(const Duration(milliseconds: 100));

    final Completer<void> authSettledCompleter = Completer<void>();

    // 3. Start listening for auth changes
    _authSubscription = _auth.userChanges().listen((user) {
      if (kDebugMode) {
        print('DEBUG-STREAM: userChanges() emitted user=${user?.uid}');
      }
      
      if (user != null) {
        _user = user;
        if (user.isAnonymous) {
          _status = AuthStatus.guest;
        } else if (!user.emailVerified) {
          _status = AuthStatus.unverified;
        } else {
          _status = AuthStatus.authenticated;
        }

        _updateCache(user.uid, _status.name, displayName: user.displayName);
        _markOnboardingComplete();
        if (!authSettledCompleter.isCompleted) authSettledCompleter.complete();
        notifyListeners();
      } else if (_isSettingsLoaded) {
        // Only allow "unauthenticated" from the stream AFTER initial startup is done
        _user = null;
        _status = AuthStatus.unauthenticated;
        _clearCache();
        notifyListeners();
      }
    });

    // 4. Check current user from cache (Fast Path)
    User? currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      currentUser = _auth.currentUser;
    }

    if (currentUser != null) {
      if (kDebugMode) print('DEBUG-INIT: Found user in Firebase cache: ${currentUser.uid}');
      _user = currentUser;
      if (currentUser.isAnonymous) {
        _status = AuthStatus.guest;
      } else if (!currentUser.emailVerified) {
        _status = AuthStatus.unverified;
      } else {
        _status = AuthStatus.authenticated;
      }
      _updateCache(currentUser.uid, _status.name, displayName: currentUser.displayName);
      _markOnboardingComplete();
      if (!authSettledCompleter.isCompleted) authSettledCompleter.complete();
    } else {
      // 5. Fallback Path: Only if no user found, try Google silent restore
      _tryGoogleFallback(authSettledCompleter);
    }

    // 6. Final wait for resolution or timeout
    try {
      await authSettledCompleter.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      if (kDebugMode) print('DEBUG-INIT: Initialization timeout reached');
    } finally {
      // 7. Robust Final State Resolution
      // Double check currentUser one last time before giving up
      if (_user == null && _auth.currentUser != null) {
         _user = _auth.currentUser;
         _status = _user!.isAnonymous ? AuthStatus.guest : AuthStatus.authenticated;
      }

      // If we still haven't found a user AND don't have a cached one, default to unauthenticated
      if (_status == AuthStatus.initial && _cachedUid == null) {
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
      
      _isSettingsLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _updateCache(String uid, String status, {String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_uid', uid);
    await prefs.setString('last_known_status', status);
    if (displayName != null) await prefs.setString('last_known_name', displayName);
    _cachedUid = uid;
    _cachedDisplayName = displayName ?? _cachedDisplayName;
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_known_uid');
    await prefs.remove('last_known_status');
    await prefs.remove('last_known_name');
    _cachedUid = null;
    _cachedDisplayName = null;
  }

  Future<void> _tryGoogleFallback(Completer<void> completer) async {
    try {
      final googleUser = await _googleSignIn.signInSilently().timeout(const Duration(seconds: 5));
      if (googleUser != null && !completer.isCompleted) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      if (kDebugMode) print('DEBUG-INIT: Google fallback skipped or failed: $e');
    }
  }

  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingComplete = prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingComplete, true);
    notifyListeners();
  }

  Future<void> _markOnboardingComplete() async {
    if (!_onboardingComplete) {
      await completeOnboarding();
    }
  }

  Future<void> refreshUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await currentUser.reload();
      _user = _auth.currentUser;
      notifyListeners();
    }
  }

  Future<bool> continueAsGuest() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _auth.signInAnonymously();
      _user = result.user;
      _status = AuthStatus.guest;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Guest access failed.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = result.user;
      await _user?.reload();
      _user = _auth.currentUser;

      if (!(_user?.emailVerified ?? false)) {
        _status = AuthStatus.unverified;
      } else {
        _status = AuthStatus.authenticated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await result.user?.updateDisplayName(name);
      await result.user?.sendEmailVerification();
      
      _user = _auth.currentUser;
      _status = AuthStatus.unverified;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isGoogleLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. SIGN IN with timeout to prevent infinite spinner
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 45), 
        onTimeout: () => throw TimeoutException('Sign in timed out'),
      );

      if (googleUser == null) {
        _isGoogleLoading = false;
        notifyListeners();
        return false;
      }

      // 2. GET AUTHENTICATION
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. FIREBASE SIGN IN
      final result = await _auth.signInWithCredential(credential);
      _user = result.user;
      _status = AuthStatus.authenticated;

      if (_user != null) {
        await _updateCache(_user!.uid, _status.name, displayName: _user?.displayName);
      }

      _isGoogleLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
    } catch (e) {
      if (e is TimeoutException) {
        _error = "Connection timed out. Please try again.";
      } else {
        _error = "Google Sign-In failed.";
      }
    }

    _isGoogleLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _status = AuthStatus.unauthenticated;
      _user = null;
      await _clearCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Check your email and try again.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> isEmailVerified() async {
    await _auth.currentUser?.reload();
    _user = _auth.currentUser;
    if (_user?.emailVerified ?? false) {
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return true;
    } catch (_) {
      _error = "Too many requests. Try again later.";
      notifyListeners();
      return false;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No user found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'invalid-credential': return 'Invalid email or password.';
      case 'email-already-in-use': return 'Email already registered.';
      case 'network-request-failed': return 'Please check your internet connection and try again.';
      case 'too-many-requests': return 'Too many requests. Try again later.';
      default: return 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
