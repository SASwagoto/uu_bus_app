// lib/services/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LocationService {
  // Singleton Pattern (যাতে পুরো অ্যাপে একটা মাত্র ইনস্ট্যান্সই চলে)
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final ApiService _apiService = ApiService();
  Timer? _globalLocationTimer;

  /// 🚀 ড্রাইভারের গ্লোবাল ট্র্যাকিং শুরু করার মেথড
  Future<void> startGlobalTracking() async {
    // যদি অলরেডি টাইমার চলতে থাকে, তবে নতুন করে চালু করার দরকার নেই
    if (_globalLocationTimer != null && _globalLocationTimer!.isActive) {
      return;
    }

    print("🛰️ [LocationService] গ্লোবাল লোকেশন ট্র্যাকিং ব্যাকগ্রাউন্ডে চালু হচ্ছে...");

    // ⏱️ প্রতি ৬০ সেকেন্ড (১ মিনিট) পর পর কারেন্ট লোকেশন পাঠানো
    _globalLocationTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      await _checkAndSendLocation();
    });
  }

  /// 🛑 ট্র্যাকিং স্টপ করার মেথড (যেমন: ড্রাইভার লগআউট করলে বা ট্রিপ না থাকলে)
  void stopGlobalTracking() {
    _globalLocationTimer?.cancel();
    _globalLocationTimer = null;
    print("🛑 [LocationService] গ্লোবাল লোকেশন ট্র্যাকিং স্টপ করা হয়েছে।");
  }

  /// ভেতরের লজিক যা লোকেশন চেক করে ব্যাকএন্ডে পাঠাবে
  Future<void> _checkAndSendLocation() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // ১. ইউজার ড্রাইভার কিনা এবং তার কোনো ট্রিপ একটিভ আছে কিনা চেক করা
      // (ড্রাইভার ট্রিপ স্টার্ট করার সময় এই Shared Preference 'is_trip_active' = true এবং 'active_trip_id' সেভ করে রাখবেন)
      bool isTripActive = prefs.getBool('is_trip_active') ?? false;
      int tripId = prefs.getInt('active_trip_id') ?? 0;
      String? role = prefs.getString('user_role'); // ড্রাইভার নাকি প্যাসেঞ্জার চেক

      if (role != 'driver' || !isTripActive || tripId == 0) {
        // যদি ড্রাইভার ট্রিপে না থাকে, তবে এপিআই কল করার দরকার নেই
        return;
      }

      // ২. জিপিএস পারমিশন চেক করা
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      // ৩. কারেন্ট লোকেশন গেট করা
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // ৪. লারাভেল ব্যাকএন্ডে লাইভ লোকেশন পুশ করা
      await _apiService.updateDriverLocation(
        tripId: tripId,
        lat: position.latitude,
        lng: position.longitude,
      );

      print("⏱️ [১ মিনিটের গ্লোবাল আপডেট] Trip ID: $tripId | Lat: ${position.latitude}, Lng: ${position.longitude}");

    } catch (e) {
      print("🚨 গ্লোবাল লোকেশন সার্ভিস এরর: $e");
    }
  }
}