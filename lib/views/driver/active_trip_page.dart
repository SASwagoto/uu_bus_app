// lib/views/driver/active_trip_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class ActiveTripPage extends StatefulWidget {
  const ActiveTripPage({super.key});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  Timer? _locationTimer;
  int _tripId = 0; // 💡 মেইন ট্রিপ আইডি ভ্যারিয়েবল
  bool _isEnding = false;
  bool _isLoadingTrip = true; // ট্রিপ আইডি লোড হওয়া পর্যন্ত ওয়েট করার জন্য

  // ডিফল্ট পজিশন: উত্তরা ইউনিভার্সিটি ক্যাম্পাস
  LatLng _mapCenter = const LatLng(23.8738, 90.3807);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ড্যাশবোর্ড থেকে পুশ হয়ে আসলে আইডি রিসিভ করার চেষ্টা
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['trip_id'] != null) {
      setState(() {
        _tripId = args['trip_id'];
        _isLoadingTrip = false;
      });
    } else {
      // 💡 যদি আইডি আর্গুমেন্টসে না পাওয়া যায় (যেমন: ডিরেক্ট রিডাইরেক্ট), তবে লারাভেল থেকে আইডি টেনে আনা হবে
      _fetchActiveTripFromBackend();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndStart();
  }

  // 💡 লারাভেল ব্যাকএন্ড থেকে কারেন্ট একটিভ ট্রিপের সঠিক আইডি লোড করার ফুলপ্রুফ মেথড
  Future<void> _fetchActiveTripFromBackend() async {
    try {
      // আপনার এপিআই সার্ভিসের কারেন্ট একটিভ ট্রিপ মেথডটি কল করা হচ্ছে
      final response = await _apiService.getCurrentDriverActiveTrip();
      if (response != null && response['has_active_trip'] == true) {
        setState(() {
          _tripId = response['trip']['id']; // ডাটাবেজ থেকে আসল আইডি সেভ হলো
          _isLoadingTrip = false;
        });
        print("🎯 ব্যাকএন্ড থেকে উদ্ধারকৃত আসল ট্রিপ আইডি: $_tripId");
      } else {
        setState(() => _isLoadingTrip = false);
        _showSnackBar('কোনো সচল ট্রিপ খুঁজে পাওয়া যায়নি!', AppColors.danger);
      }
    } catch (e) {
      setState(() => _isLoadingTrip = false);
      print("ট্রিপ আইডি লোড করতে সমস্যা: $e");
    }
  }

  Future<void> _checkLocationPermissionAndStart() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('দয়া করে ফোনের GPS লোকেশন অন করুন।', AppColors.danger);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('লোকেশন পারমিশন না দিলে বাস ট্র্যাক করা যাবে না।', AppColors.danger);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('লোকেশন পারমিশন ব্লকেড। সেটিংসে গিয়ে অন করুন।', AppColors.danger);
      return;
    }

    // প্রথমবার ইনস্ট্যান্ট কারেন্ট লোকেশন পাঠানো
    _getAndSendCurrentLocation();

    // ⏱️ প্রতি ২০ সেকেন্ড পর পর ব্যাকএন্ডে লোকেশন পাঠানো এবং ম্যাপ আপডেট করা
    _locationTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _getAndSendCurrentLocation();
    });
  }

  Future<void> _getAndSendCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      if (!mounted) return;

      LatLng newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = position;
        _mapCenter = newLocation;
      });

      _mapController.move(newLocation, 16.0);

      // 🚀 লারাভেল ব্যাকএন্ডে সঠিক আইডিতে লাইভ লোকেশন পুশ করা
      if (_tripId != 0) {
        await _apiService.updateDriverLocation(
          tripId: _tripId,
          lat: position.latitude,
          lng: position.longitude,
        );
        print("🚀 [সফল] ২০ সেকেন্ডের লাইভ লোকেশন সেন্ট -> Trip ID: $_tripId | Lat: ${position.latitude}, Lng: ${position.longitude}");
      }
    } catch (e) {
      print("লোকেশন মেথড এরর: $e");
    }
  }

  // 💡 আপনার কাঙ্ক্ষিত সম্পূর্ণ সলভড এন্ড ট্রিপ মেথড
  void _handleEndTrip() async {
    if (_tripId == 0) {
      _showSnackBar('ত্রুটি: কোনো বৈধ ট্রিপ আইডি পাওয়া যায়নি!', AppColors.danger);
      return;
    }

    print("🔴 ফ্লাটার থেকে এই ট্রিপ আইডিটি এন্ড করার চেষ্টা করা হচ্ছে: $_tripId");

    setState(() => _isEnding = true);

    // এপিআই সার্ভিসকে সঠিক আইডি পাঠানো হলো
    Map<String, dynamic> result = await _apiService.endTrip(_tripId);

    setState(() => _isEnding = false);

    if (result['success'] == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_trip_active');
      await prefs.remove('active_trip_id');

      _locationTimer?.cancel(); // টাইমার স্টপ করা হলো

      if (mounted) {
        _showSnackBar('ট্রিপ সফলভাবে সমাপ্ত হয়েছে।', AppColors.success);
        // ট্রিপ শেষে ড্রাইভার ড্যাশবোর্ডে ব্যাক করা হলো
        Navigator.pushReplacementNamed(context, '/driver_dashboard');
      }
    } else {
      if (mounted) {
        _showSnackBar(result['message'] ?? 'ট্রিপ শেষ করা যায়নি।', AppColors.danger);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রানিং ট্রিপ ট্র্যাকিং (Free Map)', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: AppColors.accent,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // 🗺️ ওপেন-স্ট্রিট-ম্যাপ উইজেট
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uttarauniversity.uu_bus_app',
              ),

              // 📍 কাস্টম আকর্ষণীয় বাস মার্কার লেয়ার
              MarkerLayer(
                markers: [
                  Marker(
                    point: _mapCenter,
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.directions_bus_rounded,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // নিচে কন্ট্রোল প্যানেল এবং এন্ড বাটন
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radar, color: AppColors.success),
                      const SizedBox(width: 8),
                      _isLoadingTrip
                          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                        'ট্রিপ আইডি: #$_tripId | ফ্রি ম্যাপ লাইভ ট্র্যাকিং',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: (_isEnding || _isLoadingTrip) ? null : _handleEndTrip,
                      child: _isEnding
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('ট্রিপ শেষ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}