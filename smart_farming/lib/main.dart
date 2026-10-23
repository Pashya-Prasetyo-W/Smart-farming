import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart'; // Import halaman login

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tani Pintar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        fontFamily: 'Inter', // Opsional: Gunakan font yang lebih modern
      ),
      home: const LoginScreen(), // Set halaman awal ke Login
    );
  }
}