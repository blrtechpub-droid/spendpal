import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/user_model.dart';
import 'package:spendpal/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String _verificationId = '';
  bool _isOtpSent = false;
  bool _isLoading = false;


Future<void> _signInWithGoogle() async {
  try {
    // New API uses .authenticate() for explicit auth
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

    // Get ID token
    final idToken = googleUser.authentication.idToken;

    // Get access token via authorization client
    final authClient = googleUser.authorizationClient;
    final authorization = await authClient.authorizationForScopes(['email', 'profile']);
    final accessToken = authorization?.accessToken;

    if (idToken == null || accessToken == null) {
      throw FirebaseAuthException(code: 'missing-token', message: 'Missing Google auth token');
    }

    // Create credential
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    print('✅ Google Sign-In successful');
    await saveUserToFirestore(userCredential.user!);
    // ✅ Navigate to Home Screen after success
    if (!mounted) return;
    //Navigator.pushReplacementNamed(context, '/groups');
    _navigateToHome();
  } catch (e) {
    print('❌ Google Sign-In error: $e');
  }
}
  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneController.text,
      verificationCompleted: (credential) async {
        //await _auth.signInWithCredential(credential);
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        await saveUserToFirestore(userCredential.user!); // ✅ Add this line
        _navigateToHome();
      },
      verificationFailed: (error) {
        Fluttertoast.showToast(msg: "OTP verification failed: ${error.message}");
        setState(() => _isLoading = false);
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyOtp() async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await saveUserToFirestore(userCredential.user!);
      _navigateToHome();
    } catch (e) {
      Fluttertoast.showToast(msg: "Invalid OTP");
    }
  }


Future<void> saveUserToFirestore(User firebaseUser) async {
  final userDoc = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
  final snapshot = await userDoc.get();

  if (!snapshot.exists) {
    final userModel = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      phone: firebaseUser.phoneNumber ?? '',
      photoURL: firebaseUser.photoURL ?? '',
      friends: {}, // Empty at login
    );

    await userDoc.set(userModel.toMap());
  }
}

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home'); // Replace with your actual route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and Title Section
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.tealAccent,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tealAccent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SpendPal',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Split expenses with friends',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Google Sign In Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.tealAccent,
                        AppTheme.tealAccent.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.tealAccent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.login, color: AppTheme.tealAccent, size: 20),
                      ),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Divider with "OR"
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppTheme.dividerColor,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppTheme.dividerColor,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Phone Number Input
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppTheme.primaryText),
                  decoration: AppTheme.inputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91xxxxxxxxxx',
                    prefixIcon: const Icon(
                      Icons.phone,
                      color: AppTheme.tealAccent,
                    ),
                  ),
                ),

                if (_isOtpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.primaryText),
                    decoration: AppTheme.inputDecoration(
                      labelText: 'Enter OTP',
                      hintText: '6-digit code',
                      prefixIcon: const Icon(
                        Icons.lock,
                        color: AppTheme.tealAccent,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Phone Auth Button
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.tealAccent,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _isOtpSent ? _verifyOtp : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cardBackground,
                          foregroundColor: AppTheme.primaryText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppTheme.tealAccent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _isOtpSent ? 'Verify OTP' : 'Send OTP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                const SizedBox(height: 40),

                // Footer
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.tertiaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
