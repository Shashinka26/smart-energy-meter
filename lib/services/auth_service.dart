import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _configRef = FirebaseDatabase.instance.ref('Config');

  String? _cachedOwnerUid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isOwner {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid == _cachedOwnerUid;
  }

  Future<void> refreshOwnerUid() async {
    final snapshot = await _configRef.child('ownerUid').get();
    final value = snapshot.value?.toString();
    _cachedOwnerUid =
        value != null && value.isNotEmpty && value != 'null' ? value : null;
  }

  Future<bool> ownerExists() async {
    await refreshOwnerUid();
    return _cachedOwnerUid != null;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await refreshOwnerUid();
    return credential;
  }

  /// First registered account becomes owner. All later accounts are viewers.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    await refreshOwnerUid();
    final claimOwner = _cachedOwnerUid == null;

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (claimOwner) {
      try {
        await _configRef.child('ownerUid').set(credential.user!.uid);
        _cachedOwnerUid = credential.user!.uid;
      } catch (e) {
        await credential.user?.delete();
        rethrow;
      }
    }

    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _cachedOwnerUid = null;
  }
}
