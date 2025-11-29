import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/car_provider.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (context) => UserProvider(),
          update: (context, auth, previous) => previous!..fetchUserProfileIfAuthenticated(auth.isAuthenticated),
        ),
        ChangeNotifierProvider(create: (context) => CarProvider()),
        ChangeNotifierProvider(create: (context) => HomeProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Car Rental App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1CE88A), brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, child) {
            return auth.isAuthenticated ? const MainScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}

extension UserProviderExtension on UserProvider {
  void fetchUserProfileIfAuthenticated(bool isAuthenticated) {
    if (isAuthenticated) {
      fetchUserProfile();
    }
  }
}