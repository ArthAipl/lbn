import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lbn/screens/getstartedscreen.dart';
import 'package:lbn/screens/spalshscreen.dart';
import 'package:lbn/adminscreen/admindashboard.dart';
import 'package:lbn/userscreens/userdashboard.dart';

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
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/get-started': (context) => const GetStartedScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/user-dashboard': (context) => const UserDashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}