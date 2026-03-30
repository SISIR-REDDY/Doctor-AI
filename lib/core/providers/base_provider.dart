import 'package:flutter/foundation.dart';

class BaseProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;
  bool get hasError => (_errorMessage ?? '').isNotEmpty;

  @protected
  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  @protected
  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  @protected
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}

class DataState<T> {
  final T? data;
  final bool isLoading;
  final String? error;

  DataState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  bool get hasError => (error ?? '').isNotEmpty;
}

class PaginatedState<T> {
  final List<T> data;
  final bool isLoading;
  final String? error;
  final bool hasMore;

  PaginatedState({
    List<T>? data,
    List<T>? items,
    this.isLoading = false,
    this.error,
    this.hasMore = false,
  }) : data = data ?? items ?? <T>[];

  bool get hasError => (error ?? '').isNotEmpty;
  bool get isEmpty => data.isEmpty;
  List<T> get items => data;
}
