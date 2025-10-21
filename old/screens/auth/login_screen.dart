import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  void _signInWithGoogle() {
    // TODO: Implement Firebase Google Sign-In logic
    print("Google Sign-In triggered");
  }

  void _signInWithPhone(BuildContext context) {
    // TODO: Implement Firebase Phone Auth logic
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SpendPal Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome to SpendPal", style: TextStyle(fontSize: 24)),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.login),
              label: Text("Login with Google"),
              onPressed: _signInWithGoogle,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.phone),
              label: Text("Login with Phone Number"),
              onPressed: () => _signInWithPhone(context),
            ),
          ],
        ),
      ),
    );
  }
}
