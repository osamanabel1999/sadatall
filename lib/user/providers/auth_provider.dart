import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/notification_utils.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> checkAuthStatus() async {
    _setLoading(true);

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        // Try to get user data first (for user app)
        final user = await _authService.getCurrentUser();
        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          
          // Subscribe to notifications
          if (_currentUser != null) {
            NotificationUtils.subscribeToOrderNotifications(_currentUser!.id);
          }
        } else {
          _isAuthenticated = false;
        }
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _isAuthenticated = false;
    }

    _setLoading(false);
  }

  // User login method
  Future<bool> loginUser(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;
        _isAuthenticated = true;

        // Subscribe to notifications
        if (_currentUser != null) {
          NotificationUtils.subscribeToOrderNotifications(_currentUser!.id);
        }

        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.error ?? 'فشل تسجيل الدخول';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> logout() async {
    _setLoading(true);

    try {
      await _authService.logout();
      _currentUser = null;
      _isAuthenticated = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _authService.deleteAccount();
      if (result.success) {
        _currentUser = null;
        _isAuthenticated = false;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.error ?? 'تعذر حذف الحساب';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء حذف الحساب: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  User? get user => _currentUser;

  // User signup method
  Future<bool> signupUser({
    required String userName,
    required String email,
    required String phoneNumber,
    required String password,
    required String address,
    required String neighborhoodId,
  }) async {
    _setLoading(true);

    try {
      final result = await _authService.signup(
        userName: userName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        address: address,
        neighborhoodId: neighborhoodId,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;
        _isAuthenticated = true;
        
        // Subscribe to notifications
        if (_currentUser != null) {
          NotificationUtils.subscribeToOrderNotifications(_currentUser!.id);
        }
        
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}