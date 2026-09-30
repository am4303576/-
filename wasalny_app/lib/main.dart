import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/manager/manager_dashboard_screen.dart';
import 'screens/captain/captain_dashboard_screen.dart';
import 'screens/customer/customer_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const WasalnyApp(),
    ),
  );
}

class WasalnyApp extends StatelessWidget {
  const WasalnyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصلني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      // Full RTL Configuration
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [
        Locale('ar', 'IQ'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }

          final user = auth.currentUser;
          if (user == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Route according to user role
          if (user.isAdmin) {
            return const AdminDashboardScreen();
          } else if (user.isManager || user.isKitchen) {
            return ManagerDashboardScreen(restaurantId: user.restaurantId ?? '');
          } else if (user.isCaptain) {
            return const CaptainDashboardScreen();
          } else {
            return const CustomerHomeScreen();
          }
        },
      ),
    );
  }
}
