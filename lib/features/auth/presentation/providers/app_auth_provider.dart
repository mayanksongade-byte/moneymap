import 'package:flutter/material.dart';
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
  String? _error;
  AuthStatus _status = AuthStatus.initial;
  StreamSubscription<User?>? _authSubscription;
  bool _onboardingComplete = false;
  bool _isSettingsLoaded = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthStatus get status => _status;
  bool get isGuest => _user != null && _user!.isAnonymous;
  bool get onboardingComplete => _onboardingComplete;
  bool get isInitialized => _status != AuthStatus.initial && _isSettingsLoaded;

  AppAuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load onboarding status from storage
    await _loadOnboardingStatus();

    // 2. Check for existing session immediately to avoid flicker/delay
    final currentUser = _auth.currentUser;
    print('DEBUG-INIT: currentUser on cold start = ${currentUser?.uid}, isAnonymous=${currentUser?.isAnonymous}, email=${currentUser?.email}');
    
    if (currentUser != null) {
      _user = currentUser;
      if (currentUser.isAnonymous) {
        _status = AuthStatus.guest;
      } else if (!currentUser.emailVerified) {
        _status = AuthStatus.unverified;
      } else {
        _status = AuthStatus.authenticated;
      }
      _markOnboardingComplete();
    } else {
      // FALLBACK: currentUser is null - this can happen on Samsung devices due to
      // an Android Keystore reliability issue affecting Firebase's encrypted token
      // storage. Try to silently restore the session via Google Sign-In's own
      // credential cache (separate from Firebase's Keystore-based storage) before
      // concluding the user is logged out.
      try {
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final result = await _auth.signInWithCredential(credential);
          if (result.user != null) {
            _user = result.user;
            _status = AuthStatus.authenticated;
            _markOnboardingComplete();
            print('DEBUG-INIT: Session restored via Google Silent Sign-In fallback');
          } else {
            _status = AuthStatus.unauthenticated;
          }
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } catch (e) {
        // Silent restore failed - genuinely not logged in (or no network for
        // Google's silent check), fall back to unauthenticated.
        print('DEBUG-INIT: Google silent restore fallback failed: $e');
        _status = AuthStatus.unauthenticated;
      }
    }

    final Completer<void> authInitialCompleter = Completer<void>();

    // 3. Listen for auth changes and wait for the settled state.
    _authSubscription = _auth.userChanges().listen((user) {
      print('DEBUG-STREAM: userChanges() emitted user=${user?.uid}, isAnonymous=${user?.isAnonymous}, email=${user?.email}');
      
      // If we already have a valid user from currentUser, and the stream sends null 
      // immediately after start (common in Firebase), we ignore it briefly 
      // UNLESS the stream consistently says null.
      if (user == null && _user != null && !authInitialCompleter.isCompleted) {
        print('DEBUG-STREAM: Ignoring initial null as we have a valid currentUser');
        return;
      }

      if (_user?.uid == user?.uid && _status != AuthStatus.initial) {
        if (!authInitialCompleter.isCompleted) authInitialCompleter.complete();
        return;
      }

      _user = user;
      if (user == null) {
        _status = AuthStatus.unauthenticated;
      } else if (user.isAnonymous) {
        _status = AuthStatus.guest;
        _markOnboardingComplete();
      } else if (!user.emailVerified) {
        _status = AuthStatus.unverified;
      } else {
        _status = AuthStatus.authenticated;
        _markOnboardingComplete();
      }

      if (!authInitialCompleter.isCompleted) {
        authInitialCompleter.complete();
      }
      notifyListeners();
    });

    // 4. Wait for the real settled state.
    try {
      // If we already found a user via currentUser, we can be more confident,
      // but we still wait for the stream to confirm or time out.
      await authInitialCompleter.future.timeout(
        Duration(seconds: currentUser != null ? 2 : 4),
      );
    } catch (e) {
      if (_status == AuthStatus.initial) {
        _status = AuthStatus.unauthenticated;
      }
    }

    _isSettingsLoaded = true;
    notifyListeners();
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      print('DEBUG-GOOGLE: Signed in successfully. UID=${result.user?.uid}, isAnonymous=${result.user?.isAnonymous}, providerData=${result.user?.providerData.map((p) => p.providerId).toList()}');
      _user = result.user;
      _status = AuthStatus.authenticated;

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
    } catch (e) {
      _error = "Google Sign-In failed.";
    }

    _isLoading = false;
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
      default: return 'Authentication failed.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
