import 'package:flutter/material.dart';

import '../models/activity_models.dart';
import '../models/reference_models.dart';
import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/web_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _userService = UserService();
  final _currencyService = CurrencyService();
  final _notifService = NotificationService();

  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  List<UserLicense> _licenses = [];
  List<UserPrivilege> _privileges = [];
  List<UserCrewAssignment> _crewAssignments = [];
  List<UserTobCapability> _tobCapabilities = [];
  Map<String, CurrencyStatus> _currency = {};
  int _unreadNotifications = 0;

  List<HelicopterType> _helicopterTypes = [];
  List<PrivilegeType> _privilegeTypes = [];
  List<LicenseType> _licenseTypes = [];
  List<TobCapability> _tobCapabilityTypes = [];
  List<OrgUnit> _orgUnits = [];

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

  bool get hasTCrew => _crewAssignments.any((item) => item.crewType == 'T');
  bool get hasTobCrew => _crewAssignments.any((item) => item.crewType == 'TOB');
  bool get hasMdbCrew => _crewAssignments.any((item) => item.crewType == 'MDB');

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadReferenceData();
      final session = await _authService.loadSession();
      final userId = session?['userId'];
      if (userId != null) {
        await WebNotificationService.requestPermission();
        await _loadUserData(userId);
        if (_userProfile == null) {
          await _authService.signOut();
        } else if (_userProfile!.nome.startsWith('ENC:') ||
            _userProfile!.cognome.startsWith('ENC:')) {
          // Sessione obsoleta con chiave di cifratura diversa: forza logout
          await _authService.signOut();
          _userProfile = null;
        }
      }
    } catch (e) {
      _error = _parseError(e);
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
    _licenses = [];
    _privileges = [];
    _crewAssignments = [];
    _tobCapabilities = [];
    _currency = {};
    _unreadNotifications = 0;

    _userProfile = await _userService.getUserProfile(userId);
    if (_userProfile == null) {
      return;
    }

    if (_userProfile!.isUser || _userProfile!.isApproved) {
      await Future.wait([
        _userService.getUserLicenses(userId).then((value) => _licenses = value),
        _userService
            .getUserPrivileges(userId)
            .then((value) => _privileges = value),
        _userService
            .getUserCrewAssignments(userId)
            .then((value) => _crewAssignments = value),
        _userService
            .getUserTobCapabilities(userId)
            .then((value) => _tobCapabilities = value),
      ]);

      _currency = await _currencyService.getFullCurrency(
        userId,
        _tobCapabilities,
      );
      await _currencyService.checkAndNotify(userId, _tobCapabilities);
      _unreadNotifications = await _notifService.getUnreadCount(userId);
      await _notifService.syncUnreadSystemNotifications(userId);
    }
  }

  Future<bool> signIn(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.signIn(username, password);
      if (_userProfile == null) {
        _error = 'Credenziali non valide';
        return false;
      }

      await _loadReferenceData();
      await _authService.saveSession(_userProfile!.id, _userProfile!.role);
      await WebNotificationService.requestPermission();
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
    required String password,
    required String nome,
    required String cognome,
    required String numeroLicenza,
    required String email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.signUp(
        password: password,
        nome: nome,
        cognome: cognome,
        numeroLicenza: numeroLicenza,
        email: email,
      );
      await _loadReferenceData();
      await _authService.saveSession(_userProfile!.id, _userProfile!.role);
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
    final userId = _userProfile?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }
    await _authService.changePassword(userId, newPassword);
  }

  Future<void> refreshUserData() async {
    if (_userProfile == null) {
      return;
    }

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
    await _authService.updateProfile(updated);
    final refreshed = await _userService.getUserProfile(updated.id);
    if (refreshed == null) {
      throw Exception('Profilo non trovato dopo l\'aggiornamento');
    }
    _userProfile = refreshed;
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
    if (msg.contains('invalid credentials') || msg.contains('credenziali')) {
      return 'Identificativo o password non corretti';
    }
    if (msg.contains('username già registrato') ||
        msg.contains('username already') ||
        msg.contains('numero di licenza già registrato') ||
        (msg.contains('unique') && msg.contains('numero_licenza'))) {
      return 'Numero licenza / username già registrato';
    }
    if (msg.contains('account disabilitato')) {
      return 'Account disabilitato';
    }
    return 'Errore: ${e.toString()}';
  }
}
