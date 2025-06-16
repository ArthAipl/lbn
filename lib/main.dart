import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lbn/screens/getstartedscreen.dart';
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
        textTheme: GoogleFonts.poppinsTextTheme(), // Set Poppins globally
        useMaterial3: true, // Optional: Enables Material 3
      ),
      home: const SplashScreen(),
      routes: {
        '/get-started': (context) => const GetStartedScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
