import 'package:flutter/material.dart';
import 'package:lbn/screens/getstartedscreen.dart';
import 'package:lbn/screens/loginscreen.dart';
import 'package:lbn/screens/signupscreen.dart';
import 'package:lbn/screens/spalshscreen.dart';

void main() {
  runApp(const LBNApp());
}

class LBNApp extends StatelessWidget {
  const LBNApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LBN Business Network',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      home: const SplashScreen(),
      routes: {
        '/get-started': (context) => const GetStartedScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}