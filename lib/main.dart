import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_colors.dart';
import 'views/auth/driver_login_page.dart';
import 'views/auth/passenger_login_page.dart';
import 'views/auth/passenger_register_page.dart';
import 'views/driver/driver_dashboard.dart';
import 'views/driver/active_trip_page.dart';
import 'views/passenger/passenger_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  String? token = prefs.getString('auth_token');
  String? role = prefs.getString('user_role');
  bool isDriverRunningTrip = prefs.getBool('is_trip_active') ?? false;

  // ডিফল্ট হোম স্ক্রিন নির্ধারণ লজিক
  Widget initialRoute = const PassengerLoginPage(); // ডিফল্ট স্টার্ট পেজ

  if (token != null) {
    if (role == 'driver') {
      // ড্রাইভার যদি ট্রিপ এন্ড না করে অ্যাপ ক্লোজ করে দেয়, সে সরাসরি একটিভ ট্রিপ পেজে যাবে
      initialRoute = isDriverRunningTrip ? const ActiveTripPage() : const DriverDashboard();
    } else if (role == 'passenger') {
      initialRoute = const PassengerDashboard();
    }
  }

  runApp(UUBusApp(initialScreen: initialRoute));
}

class UUBusApp extends StatelessWidget {
  final Widget initialScreen;
  const UUBusApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UU Bus Manage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto', // আপনার পছন্দের ফন্ট দিতে পারেন
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      home: initialScreen,
      routes: {
        '/passenger_login': (context) => const PassengerLoginPage(),
        '/driver_login': (context) => const DriverLoginPage(),
        '/passenger_register': (context) => const PassengerRegisterPage(),
        '/driver_dashboard': (context) => const DriverDashboard(),
        '/active_trip_page': (context) => const ActiveTripPage(),
        '/passenger_dashboard': (context) => const PassengerDashboard(),
      },
    );
  }
}