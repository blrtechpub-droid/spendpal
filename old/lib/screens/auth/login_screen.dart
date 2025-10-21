import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gs;
import 'package:fluttertoast/fluttertoast.dart';

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
      final gs.GoogleSignInAccount? googleUser =
          await gs.GoogleSignIn.instance.signIn();

      if (googleUser == null) {
        Fluttertoast.showToast(msg: "Google sign-in cancelled");
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _navigateToHome();
    } catch (e) {
      Fluttertoast.showToast(msg: "Google sign-in error: $e");
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneController.text,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
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
      await _auth.signInWithCredential(credential);
      _navigateToHome();
    } catch (e) {
      Fluttertoast.showToast(msg: "Invalid OTP");
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home'); // Replace with your actual route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login to SpendPal")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text("Sign in with Google"),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (+91xxxxxxxxxx)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_isOtpSent)
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _isOtpSent ? _verifyOtp : _sendOtp,
                    child: Text(_isOtpSent ? 'Verify OTP' : 'Send OTP'),
                  ),
          ],
        ),
      ),
    );
  }
}
