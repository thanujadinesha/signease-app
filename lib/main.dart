import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/sign_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/signature_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const iSignerApp());
}

class iSignerApp extends StatelessWidget {
  const iSignerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SignProvider()),
      ],
      child: MaterialApp(
        title: 'iSigner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: Color(0xFF0E0E14),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          ),
        );
      case AuthStatus.authenticated:
        return const SignatureScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
