import 'package:flutter/foundation.dart';

import 'base_provider.dart';

enum ConnectionStatus {
  online,
  offline,
  syncing,
}

class EnhancedConnectionProvider extends BaseProvider {
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  DateTime? _lastSuccessfulSync;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;

  ConnectionStatus get status {
    if (!_isOnline) return ConnectionStatus.offline;
    if (_isSyncing) return ConnectionStatus.syncing;
    return ConnectionStatus.online;
  }

  String get statusLabel {
    switch (status) {
      case ConnectionStatus.online:
        return 'Online';
      case ConnectionStatus.offline:
        return 'Offline';
      case ConnectionStatus.syncing:
        return 'Syncing';
    }
  }

  Future<void> initialize() async {
    _isOnline = true;
    notifyListeners();
  }

  Future<void> forceSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    _isSyncing = false;
    _pendingSyncCount = 0;
    _lastSuccessfulSync = DateTime.now();
    notifyListeners();
  }

  Map<String, dynamic> getEnhancedSyncStatistics() {
    return <String, dynamic>{
      'status': status,
      'statusLabel': statusLabel,
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'pendingSyncCount': _pendingSyncCount,
      'lastSuccessfulSync': _lastSuccessfulSync,
    };
  }

  @visibleForTesting
  void setPendingSyncCount(int count) {
    _pendingSyncCount = count;
    notifyListeners();
  }
}
