// lib/views/passenger/passenger_track_bus.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class PassengerTrackBus extends StatefulWidget {
  final int tripId;
  const PassengerTrackBus({super.key, this.tripId = 0});

  @override
  State<PassengerTrackBus> createState() => _PassengerTrackBusState();
}

class _PassengerTrackBusState extends State<PassengerTrackBus> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  Timer? _trackingTimer;
  bool _isLoading = true;
  bool _isActionLoading = false;

  // 💡 ট্র্যাকিং স্টেট ভ্যারিয়েবলস
  bool _hasCheckedInHere = false;
  bool _hasCheckedInElsewhere = false;

  int _tripId = 0;
  LatLng _busLocation = const LatLng(23.8738, 90.3807);
  String _busNumber = 'Loading...';
  String _routeName = 'Loading...';
  int _passengerCount = 0;
  String _statusText = 'বাসের লাইভ লোকেশন খোঁজা হচ্ছে...';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tripId == 0) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['trip_id'] != null) {
        _tripId = args['trip_id'];
      } else {
        _tripId = widget.tripId;
      }
      _initialFetch();
      _startTrackingTimer();
    }
  }

  // প্রথমবার লোকেশন ও চেক-ইন স্ট্যাটাস একসাথে আনা
  Future<void> _initialFetch() async {
    await _checkUserCheckInStatus();
    await _fetchLiveLocation();
  }

  void _startTrackingTimer() {
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _fetchLiveLocation();
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  // 💡 ব্যাকএন্ড থেকে ইউজারের লাইভ চেক-ইন স্ট্যাটাস লক চেক করা
  Future<void> _checkUserCheckInStatus() async {
    if (_tripId == 0) return;
    try {
      final res = await _apiService.getPassengerTripStatus(_tripId);
      if (res != null && res['success'] == true) {
        setState(() {
          _hasCheckedInHere = res['is_checked_in_here'] ?? false;
          _hasCheckedInElsewhere = res['has_active_check_in_elsewhere'] ?? false;
        });
      }
    } catch (e) {
      print("চেক-ইন স্ট্যাটাস চেক এরর: $e");
    }
  }

  Future<void> _fetchLiveLocation() async {
    if (_tripId == 0) return;
    try {
      final response = await _apiService.getTripLiveDetails(_tripId);
      if (!mounted) return;

      if (response != null && response['success'] == true) {
        final tripData = response['trip'];
        if (tripData == null) return;

        final busData = tripData['bus'];
        final routeData = tripData['route'];

        double lat = double.tryParse(tripData['current_latitude']?.toString() ?? '23.8738') ?? 23.8738;
        double lng = double.tryParse(tripData['current_longitude']?.toString() ?? '90.3807') ?? 90.3807;
        final newLocation = LatLng(lat, lng);

        setState(() {
          _busLocation = newLocation;
          _busNumber = busData != null ? busData['bus_number']?.toString() ?? 'N/A' : 'N/A';
          _routeName = routeData != null ? routeData['route_name']?.toString() ?? 'N/A' : 'N/A';
          _passengerCount = int.tryParse(tripData['passenger_count']?.toString() ?? '0') ?? 0;
          _statusText = 'লাইভ ট্র্যাকিং সচল আছে';
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(newLocation, 16.0);
        });
      }
    } catch (e) {
      print("লোকেশন লোড করতে ত্রুটি: $e");
    }
  }

  Future<void> _handleCheckIn() async {
    if (_tripId == 0 || _hasCheckedInHere || _hasCheckedInElsewhere) return;
    setState(() => _isActionLoading = true);

    final result = await _apiService.passengerCheckIn(_tripId);
    if (!mounted) return;

    if (result != null && result['success'] == true) {
      setState(() {
        _hasCheckedInHere = true;
        _isActionLoading = false;
      });

      if (result['is_overloaded'] == true) {
        _showSnackBar(result['message'], Colors.orange.shade800);
      } else {
        _showSnackBar(result['message'], AppColors.success);
      }
      _initialFetch();
    } else {
      setState(() => _isActionLoading = false);
      _showSnackBar(result?['message'] ?? 'চেক-ইন ব্যর্থ হয়েছে।', AppColors.danger);
      _initialFetch(); // সিংক্রোনাইজেশন ঠিক রাখার জন্য রিফ্রেশ
    }
  }

  Future<void> _handleCheckOut() async {
    if (_tripId == 0 || !_hasCheckedInHere) return;
    setState(() => _isActionLoading = true);

    final result = await _apiService.passengerCheckOut(_tripId);
    if (!mounted) return;

    if (result != null && result['success'] == true) {
      setState(() {
        _hasCheckedInHere = false;
        _isActionLoading = false;
      });
      _showSnackBar(result['message'], AppColors.accent);
      _initialFetch();
    } else {
      setState(() => _isActionLoading = false);
      _showSnackBar(result?['message'] ?? 'চেক-আউট ব্যর্থ হয়েছে।', AppColors.danger);
      _initialFetch();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('বাস ট্র্যাকিং (#$_tripId)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('রুট: $_routeName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Stack(
        children: [
          // 🗺️ লোকেশন সবসময় ফ্রিতে দেখা যাবে (নো রেস্ট্রিকশন)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _busLocation, initialZoom: 15.5),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uttarauniversity.uu_bus_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _busLocation,
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withOpacity(0.25)),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]),
                        ),
                        const Icon(Icons.directions_bus_rounded, color: Colors.orange, size: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // টপ ফ্লোটিং ইন্ডিকেটর
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: AppColors.success, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          const Text('প্রতি ১০ সেকেন্ড পর পর ম্যাপ আপডেট হচ্ছে', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1)),
                      icon: const Icon(Icons.my_location_rounded, color: AppColors.accent, size: 20),
                      onPressed: () => _mapController.move(_busLocation, 16.0),
                    )
                  ],
                ),
              ),
            ),
          ),

          // 🎯 বটম ডাইনামিক রেস্ট্রিক্টেড কন্ট্রোল প্যানেল
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 1)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('চলমান বাস নাম্বার', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(_busNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text('যাত্রী: $_passengerCount জন', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 💡 স্মার্ট কন্ডিশনাল বাটন ডিজাইন
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasCheckedInElsewhere
                            ? Colors.grey.shade400 // অন্য বাসে থাকলে বাটন গ্রেড-আউট বা ডিজেবলড লুক পাবে
                            : (_hasCheckedInHere ? AppColors.danger : AppColors.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      // কন্ডিশনাল অন-প্রেস লজিক লক
                      onPressed: _isActionLoading
                          ? null
                          : (_hasCheckedInElsewhere
                          ? null // অন্য বাসে ইন থাকলে বাটন ডিজেবলড
                          : (_hasCheckedInHere ? _handleCheckOut : _handleCheckIn)),
                      icon: _isActionLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(
                        _hasCheckedInElsewhere
                            ? Icons.lock_rounded
                            : (_hasCheckedInHere ? Icons.logout_rounded : Icons.login_rounded),
                        color: Colors.white,
                      ),
                      label: Text(
                        _hasCheckedInElsewhere
                            ? 'আপনি অন্য বাসে একটিভ আছেন'
                            : (_hasCheckedInHere ? 'আমি বাস থেকে নেমেছি (Check Out)' : 'আমি বাসে উঠেছি (Check In)'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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