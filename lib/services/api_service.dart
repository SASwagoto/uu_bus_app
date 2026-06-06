// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiService {

  // শেয়ার্ড প্রেফারেন্সে লগইন ডাটা সেভ করার মেথড
  Future<void> _saveAuthData(String token, String role, String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_role', role);
    await prefs.setString('user_name', name);
  }

  // ১. লগইন মেথড (ড্রাইভার এবং প্যাসেঞ্জার উভয়ের জন্যই একই মেথড কাজ করবে)
  Future<Map<String, dynamic>> login(String email, String password, String expectedRole) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        String token = data['token'];
        var user = data['user'];
        String role = user['role']; // লারাভেল থেকে আসা রোল (driver/passenger)

        // রোল ভ্যালিডেশন: ড্রাইভার কি ভুল করে প্যাসেঞ্জারে লগইন করার চেষ্টা করছে?
        if (role != expectedRole) {
          return {
            'success': false,
            'message': 'অনুমতি নেই! আপনি এই প্যানেল দিয়ে লগইন করতে পারবেন না।'
          };
        }

        // লোকাল স্টোরেজে ডাটা সেভ
        await _saveAuthData(token, role, user['name']);

        return {'success': true, 'role': role};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'লগইন ব্যর্থ হয়েছে। মেইল বা পাসওয়ার্ড চেক করুন।'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'সার্ভার কানেকশন ব্যর্থ: $e'};
    }
  }

  // ২. প্যাসেঞ্জার রেজিস্ট্রেশন মেথড
  Future<Map<String, dynamic>> registerPassenger({
    required String name,
    required String email,
    required String password,
    String? studentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password, // লারাভেল ভ্যালিডেশনের জন্য
          'student_id': studentId,
          'role': 'passenger', // রেজিস্ট্রেশন শুধু প্যাসেঞ্জারের জন্য ফিক্সড
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        String token = data['token'];
        var user = data['user'];

        await _saveAuthData(token, 'passenger', user['name']);

        return {'success': true};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'রেজিস্ট্রেশন ব্যর্থ হয়েছে।'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'সার্ভার কানেকশন ব্যর্থ: $e'};
    }
  }

  Future<List<dynamic>> getSchedules() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse(ApiConfig.getSchedules),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        // যেহেতু সরাসরি লিস্ট [ {}, {} ] আসছে, তাই একে টাইপ কাস্ট করে নিচ্ছি
        if (decodedData is List) {
          return decodedData;
        }
        return [];
      } else {
        throw 'সার্ভার এরর কোড: ${response.statusCode}';
      }
    } catch (e) {
      throw 'ডাটা লোড করতে সমস্যা হয়েছে: $e';
    }
  }

  // ৪. ড্রাইভারের ট্রিপ স্টার্ট করার মেথড
  Future<Map<String, dynamic>> startTrip(int busId, int routeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse(ApiConfig.startTrip), // ট্রিপ স্টার্ট এপিআই এন্ডপয়েন্ট
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'bus_id': busId,
          'route_id': routeId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'trip_id': data['trip_id'] // লারাভেল থেকে ক্রিয়েট হওয়া ট্রিপ আইডি
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'ট্রিপ শুরু করা যায়নি।'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'সার্ভার কানেকশন এরর: $e'};
    }
  }

  Future<bool> updateDriverLocation({required int tripId, required double lat, required double lng}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse(ApiConfig.updateLocation(tripId)),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json', // 💡 JSON ফরম্যাট
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'lat': lat, // লারাভেলের রিকোয়েস্ট অনুযায়ী 'lat'
          'lng': lng, // লারাভেলের রিকোয়েস্ট অনুযায়ী 'lng'
        }),
      );

      if (response.statusCode == 200) {
        print("🚀 সার্ভার রেসপন্স: লোকেশন সফলভাবে ডাটাবেজে আপডেট হয়েছে!");
        return true;
      } else {
        print("❌ এরর কোড: ${response.statusCode} | বডি: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ নেটওয়ার্ক এরর: $e");
      return false;
    }
  }

  // ৬. রানিং ট্রিপ বন্ধ/এন্ড করার মেথড
  Future<Map<String, dynamic>> endTrip(int tripId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse(ApiConfig.endTrip(tripId)),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'ট্রিপ শেষ করতে সার্ভারে সমস্যা হয়েছে।'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'সার্ভার কানেকশন এরর: $e'};
    }
  }

  Future<List<dynamic>> getActiveTrips() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse(ApiConfig.activeTrips),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        // যদি লারাভেল সরাসরি লিস্ট পাঠায়
        if (decodedData is List) return decodedData;
        // যদি অবজেক্টের ভেতর 'active_trips' বা 'trips' কী থাকে
        if (decodedData is Map && decodedData.containsKey('active_trips')) {
          return decodedData['active_trips'] ?? [];
        }
        return [];
      }
      return [];
    } catch (e) {
      print("একটিভ ট্রিপ এপিআই এরর: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getCurrentDriverActiveTrip() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse(ApiConfig.currentActiveTrip),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'has_active_trip': false};
    } catch (e) {
      print("কারেন্ট একটিভ ট্রিপ এপিআই ত্রুটি: $e");
      return {'has_active_trip': false};
    }
  }
}