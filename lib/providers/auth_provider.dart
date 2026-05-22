import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../models/activity_models.dart';
import '../models/reference_models.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/currency_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _userService = UserService();
  final _currencyService = CurrencyService();
  final _notifService = NotificationService();

  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  // Dati utente corrente
  List<UserLicense> _licenses = [];
  List<UserPrivilege> _privileges = [];
  List<UserCrewAssignment> _crewAssignments = [];
  List<UserTobCapability> _tobCapabilities = [];
  Map<String, CurrencyStatus> _currency = {};
  int _unreadNotifications = 0;

  // Referenze
  List<HelicopterType> _helicopterTypes = [];
  List<PrivilegeType> _privilegeTypes = [];
  List<LicenseType> _licenseTypes = [];
  List<TobCapability> _tobCapabilityTypes = [];
  List<OrgUnit> _orgUnits = [];

  // Getters
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userProfile != null;
  bool get initialized => _initialized;
  String get role => _userProfile?.role ?? '';
  bool get isAdmin => _userProfile?.isAdmin ?? false;
  bool get isAdminPriv => _userProfile?.isAdminPriv ?? false;
  bool get isAdminCrew => _userProfile?.isAdminCrew ?? false;

  List<UserLicense> get licenses => _licenses;
  List<UserPrivilege> get privileges => _privileges;
  List<UserCrewAssignment> get crewAssignments => _crewAssignments;
  List<UserTobCapability> get tobCapabilities => _tobCapabilities;
  Map<String, CurrencyStatus> get currency => _currency;
  int get unreadNotifications => _unreadNotifications;

  List<HelicopterType> get helicopterTypes => _helicopterTypes;
  List<PrivilegeType> get privilegeTypes => _privilegeTypes;
  List<LicenseType> get licenseTypes => _licenseTypes;
  List<TobCapability> get tobCapabilityTypes => _tobCapabilityTypes;
  List<OrgUnit> get orgUnits => _orgUnits;

  bool get hasTCrew => _crewAssignments.any((c) => c.crewType == 'T');
  bool get hasTobCrew => _crewAssignments.any((c) => c.crewType == 'TOB');

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadReferenceData();
      final user = _authService.currentUser;
      if (user != null) {
        await _loadUserData(user.id);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadReferenceData() async {
    _helicopterTypes = await _userService.getHelicopterTypes();
    _privilegeTypes = await _userService.getPrivilegeTypes();
    _licenseTypes = await _userService.getLicenseTypes();
    _tobCapabilityTypes = await _userService.getTobCapabilities();
    _orgUnits = await _userService.getOrgUnits();
  }

  Future<void> _loadUserData(String userId) async {
    _userProfile = await _userService.getUserProfile(userId);
    if (_userProfile == null) return;

    if (_userProfile!.isUser || _userProfile!.isApproved) {
      await Future.wait([
        _userService.getUserLicenses(userId).then((v) => _licenses = v),
        _userService.getUserPrivileges(userId).then((v) => _privileges = v),
        _userService
            .getUserCrewAssignments(userId)
            .then((v) => _crewAssignments = v),
        _userService
            .getUserTobCapabilities(userId)
            .then((v) => _tobCapabilities = v),
      ]);

      _currency = await _currencyService.getFullCurrency(
        userId,
        _tobCapabilities,
      );
      _unreadNotifications = await _notifService.getUnreadCount(userId);

      // Controlla e crea notifiche automatiche
      await _currencyService.checkAndNotify(userId, _tobCapabilities);
      _unreadNotifications = await _notifService.getUnreadCount(userId);
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _userProfile = await _authService.signIn(email, password);
      if (_userProfile == null) {
        _error = 'Credenziali non valide';
        return false;
      }
      await _loadReferenceData();
      await _loadUserData(_userProfile!.id);
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String nome,
    required String cognome,
    String? numeroLicenza,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _userProfile = await _authService.signUp(
        email: email,
        password: password,
        nome: nome,
        cognome: cognome,
        numeroLicenza: numeroLicenza,
      );
      await _loadReferenceData();
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userProfile = null;
    _licenses = [];
    _privileges = [];
    _crewAssignments = [];
    _tobCapabilities = [];
    _currency = {};
    _unreadNotifications = 0;
    notifyListeners();
  }

  Future<void> changePassword(String newPassword) async {
    await _authService.changePassword(newPassword);
  }

  Future<void> refreshUserData() async {
    if (_userProfile == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadUserData(_userProfile!.id);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserProfile updated) async {
    await _userService.updateProfile(updated);
    _userProfile = updated;
    notifyListeners();
  }

  void decrementUnread() {
    if (_unreadNotifications > 0) {
      _unreadNotifications--;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Email o password non corretti';
    }
    if (msg.contains('email already')) return 'Email già registrata';
    if (msg.contains('unique') && msg.contains('numero_licenza')) {
      return 'Numero di licenza già registrato';
    }
    return 'Errore: ${e.toString()}';
  }
}
