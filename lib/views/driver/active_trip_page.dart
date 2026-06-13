// lib/views/driver/active_trip_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart'; // 💡 গ্লোবাল লোকেশন সার্ভিস ইম্পোর্ট করা হলো

class ActiveTripPage extends StatefulWidget {
  final int tripId;
  const ActiveTripPage({super.key, this.tripId = 0});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  Timer? _uiRefreshTimer; // 💡 শুধুমাত্র ম্যাপের ভেতরের নিজের মার্কার সরানোর জন্য টাইমার
  int _tripId = 0;
  bool _isEnding = false;
  bool _isLoadingTrip = true;

  // ডিফল্ট পজিশন: উত্তরা ইউনিভার্সিটি ক্যাম্পাস
  LatLng _mapCenter = const LatLng(23.8738, 90.3807);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['trip_id'] != null) {
      setState(() {
        _tripId = args['trip_id'];
        _isLoadingTrip = false;
      });
      _saveTripStateToLocal(_tripId); // 💡 আইডি পাওয়ার সাথে সাথে লোকাল স্টেটে লক করা
    } else {
      _fetchActiveTripFromBackend();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndStart();
  }

  // 💡 ট্রিপ আইডি লোকাল স্টোরেজে সেট করা যাতে সেন্ট্রাল সার্ভিস ব্যাকগ্রাউন্ডেও ট্র্যাক করতে পারে
  Future<void> _saveTripStateToLocal(int id) async {
    if (id == 0) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_trip_active', true);
    await prefs.setInt('active_trip_id', id);

    // 🚀 গ্লোবাল সেন্ট্রাল লোকেশন সার্ভিসকে এক্টিভেট বা সিঙ্ক করে দেওয়া
    LocationService().startGlobalTracking();
    print("💾 [লোকাল স্টোরেজ] ট্রিপ আইডি #$id লক করা হয়েছে এবং গ্লোবাল সার্ভিস ট্রিগারড।");
  }

  Future<void> _fetchActiveTripFromBackend() async {
    try {
      final response = await _apiService.getCurrentDriverActiveTrip();
      if (response != null && response['has_active_trip'] == true) {
        setState(() {
          _tripId = response['trip']['id'];
          _isLoadingTrip = false;
        });
        _saveTripStateToLocal(_tripId); // 💡 ব্যাকএন্ড থেকে আইডি উদ্ধার করে লোকালে লক করা
        print("🎯 ব্যাকএন্ড থেকে উদ্ধারকৃত আসল ট্রিপ আইডি: $_tripId");
      } else {
        setState(() => _isLoadingTrip = false);
        _showSnackBar('কোনো সচল ট্রিপ খুঁজে পাওয়া যায়নি!', AppColors.danger);
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
      _showSnackBar('দয়া করে ফোনের GPS লোকেশন অন করুন।', AppColors.danger);
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
      _showSnackBar('লোকেশন পারমিশন ব্লকেড। সেটিংসে গিয়ে অন করুন।', AppColors.danger);
      return;
    }

    // প্রথমবার স্ক্রিন ওপেন হওয়ার সাথে সাথে নিজের ম্যাপের পজিশন সেট করা
    _getAndUpdateUiLocation();

    // ⏱️ 💡 মডারেট UI রিফ্রেশ টাইমার (সার্ভারে রিকোয়েস্ট পাঠাবে না, শুধু নিজের চোখের সামনে স্ক্রিনের ম্যাপ মার্কার আপডেট করবে)
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _getAndUpdateUiLocation();
    });
  }

  // 💡 শুধুমাত্র ফ্রন্টএন্ড ম্যাপ রিফ্রেশ করার মেথড (নো এপিআই হিট)
  Future<void> _getAndUpdateUiLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      if (!mounted) return;

      LatLng newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _mapCenter = newLocation;
      });

      _mapController.move(newLocation, 16.0);
      print("🗺️ [UI ম্যাপ রিফ্রেশ] ড্রাইভারের স্ক্রিন ক্যামেরা মুভড -> Lat: ${position.latitude}");
    } catch (e) {
      print("UI লোকেশন রিফ্রেশ এরর: $e");
    }
  }

  void _handleEndTrip() async {
    if (_tripId == 0) {
      _showSnackBar('ত্রুটি: কোনো বৈধ ট্রিপ আইডি পাওয়া যায়নি!', AppColors.danger);
      return;
    }

    setState(() => _isEnding = true);

    Map<String, dynamic> result = await _apiService.endTrip(_tripId);

    setState(() => _isEnding = false);

    if (result['success'] == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_trip_active');
      await prefs.remove('active_trip_id');

      // 🛑 গ্লোবাল ট্র্যাকিং সার্ভিস এবং লোকাল UI টাইমার বন্ধ করা
      LocationService().stopGlobalTracking();
      _uiRefreshTimer?.cancel();

      if (mounted) {
        _showSnackBar('ট্রিপ সফলভাবে সমাপ্ত হয়েছে।', AppColors.success);
        Navigator.pushReplacementNamed(context, '/driver_dashboard');
      }
    } else {
      if (mounted) {
        _showSnackBar(result['message'] ?? 'ট্রিপ শেষ করা যায়নি।', AppColors.danger);
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
    _uiRefreshTimer?.cancel(); // লোকাল UI টাইমার ডিসপোজ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রানিং ট্রিপ ট্র্যাকিং (ফ্রি ম্যাপ)', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uttarauniversity.uu_bus_app',
              ),
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
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withOpacity(0.3)),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                          ),
                        ),
                        const Icon(Icons.directions_bus_rounded, color: Colors.orange, size: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // নিচে কন্ট্রোল প্যানেল
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