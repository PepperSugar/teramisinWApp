import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _whitelist = [
  'emirsugar1@gmail.com',
  'friend1@gmail.com',
  'friend2@gmail.com',
];

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool isWhitelisted(String? email) => _whitelist.contains(email);

  Future<AuthResult> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return AuthResult.cancelled;

    if (!isWhitelisted(googleUser.email)) {
      await _googleSignIn.signOut();
      return AuthResult.denied;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
    return AuthResult.success;
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}

enum AuthResult { success, cancelled, denied }
