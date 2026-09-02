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

  User? get user => _user;
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
    // 1. Load onboarding status
    await _loadOnboardingStatus();

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

        _markOnboardingComplete();
        if (!authSettledCompleter.isCompleted) authSettledCompleter.complete();
        notifyListeners();
      } else if (_isSettingsLoaded) {
        // Only allow "unauthenticated" from the stream AFTER initial startup is done
        _user = null;
        _status = AuthStatus.unauthenticated;
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
      if (kDebugMode) print('DEBUG-INIT: Found user: ${currentUser.uid}');
      _user = currentUser;
      if (currentUser.isAnonymous) {
        _status = AuthStatus.guest;
      } else if (!currentUser.emailVerified) {
        _status = AuthStatus.unverified;
      } else {
        _status = AuthStatus.authenticated;
      }
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
      if (_status == AuthStatus.initial) {
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
      _isSettingsLoaded = true;
      notifyListeners();
    }
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
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _isGoogleLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      _user = result.user;
      _status = AuthStatus.authenticated;

      _isGoogleLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
    } catch (e) {
      _error = "Google Sign-In failed.";
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
