// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_colors.dart';
import 'views/auth/driver_login_page.dart';
import 'views/auth/passenger_login_page.dart';
import 'views/auth/passenger_register_page.dart';
import 'views/driver/driver_dashboard.dart';
import 'views/driver/active_trip_page.dart';
import 'views/passenger/passenger_dashboard.dart';
import 'views/passenger/passenger_track_bus.dart'; // নতুন ম্যাপ পেজ ইমপোর্ট

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  String? token = prefs.getString('auth_token');
  String? role = prefs.getString('user_role');
  bool isDriverRunningTrip = prefs.getBool('is_trip_active') ?? false;
  int activeTripId = prefs.getInt('active_trip_id') ?? 0; // মেমোরি থেকে ট্রিপ আইডি লোড

  // ডিফল্ট হোম স্ক্রিন নির্ধারণ লজিক
  Widget initialRoute = const PassengerLoginPage();

  if (token != null) {
    if (role == 'driver') {
      // ড্রাইভার সেশন রানিং থাকলে সরাসরি ট্রিপ আইডি সহ অ্যাক্টিভ পেজে রিডাইরেক্ট
      initialRoute = isDriverRunningTrip
          ? ActiveTripPage(tripId: activeTripId)
          : const DriverDashboard();
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
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      home: initialScreen,

      // 💡 প্রফেশনাল এপ্রোচ: স্ট্যাটিক রাউটস (যেগুলোতে কোনো আর্গুমেন্ট পাস করতে হয় না)
      routes: {
        '/passenger_login': (context) => const PassengerLoginPage(),
        '/driver_login': (context) => const DriverLoginPage(),
        '/passenger_register': (context) => const PassengerRegisterPage(),
        '/driver_dashboard': (context) => const DriverDashboard(),
        '/passenger_dashboard': (context) => const PassengerDashboard(),
      },

      // 💡 প্রফেশনাল এপ্রোচ: ডাইনামিক রাউটস হ্যান্ডেলার (যে পেজগুলোতে আইডি বা আর্গুমেন্ট পাস করতে হয়)
      onGenerateRoute: (settings) {
        // ১. ড্রাইভারের একটিভ ট্রিপ পেজ রাউট উইথ আর্গুমেন্ট
        if (settings.name == '/active_trip_page') {
          final args = settings.arguments as Map<String, dynamic>?;
          final tripId = int.tryParse(args?['trip_id']?.toString() ?? '0') ?? 0;

          return MaterialPageRoute(
            builder: (context) => ActiveTripPage(tripId: tripId),
            settings: settings,
          );
        }

        // ২. প্যাসেঞ্জারের বাস ট্র্যাকিং ম্যাপ পেজ রাউট উইথ আর্গুমেন্ট
        if (settings.name == '/passenger_track_bus') {
          final args = settings.arguments as Map<String, dynamic>?;
          final tripId = int.tryParse(args?['trip_id']?.toString() ?? '0') ?? 0;

          return MaterialPageRoute(
            builder: (context) => PassengerTrackBus(tripId: tripId),
            settings: settings,
          );
        }

        return null; // ডিফল্ট বা আননোন রাউটের ক্ষেত্রে সেফটি ফলব্যাক
      },
    );
  }
}