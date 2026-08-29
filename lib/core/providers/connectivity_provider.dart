import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _updateState(result);

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateState(result);
    });
  }

  void _updateState(ConnectivityResult result) {
    final bool offline = result == ConnectivityResult.none;
    if (_isOffline != offline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
