import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_models.dart';
import 'user_service.dart';

class AuthService {
  final _auth = Supabase.instance.client.auth;
  final _userService = UserService();

  Future<UserProfile?> signIn(String email, String password) async {
    final res = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) return null;
    return _userService.getUserProfile(res.user!.id);
  }

  Future<UserProfile?> signUp({
    required String email,
    required String password,
    required String nome,
    required String cognome,
    String? numeroLicenza,
  }) async {
    final res = await _auth.signUp(email: email, password: password);
    if (res.user == null) throw Exception('Registrazione fallita');
    return _userService.createProfile(
      id: res.user!.id,
      nome: nome,
      cognome: cognome,
      numeroLicenza: numeroLicenza,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> changePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}
