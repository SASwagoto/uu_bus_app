// lib/views/driver/driver_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final ApiService _apiService = ApiService();

  String _driverName = "ড্রাইভার";
  List<dynamic> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDriverName();
    _checkActiveTripAndFetchSchedules(); // 💡 নতুন মেথড কল
  }

  void _loadDriverName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverName = prefs.getString('user_name') ?? "ড্রাইভার";
    });
  }

  void _checkActiveTripAndFetchSchedules() async {
    try {
      setState(() => _isLoading = true);

      // ১. সরাসরি লারাভেল ব্যাকএন্ড সার্ভার থেকে চেক করা এই ড্রাইভারের কোনো ট্রিপ রানিং আছে কি না
      Map<String, dynamic> activeTripStatus = await _apiService.getCurrentDriverActiveTrip();

      if (activeTripStatus['has_active_trip'] == true && activeTripStatus['trip'] != null) {
        var tripData = activeTripStatus['trip'];
        int activeTripId = int.tryParse(tripData['id']?.toString() ?? '0') ?? 0;

        // লোকাল মেমোরিতেও স্টেট আপডেট করে রাখা ব্যাকআপ হিসেবে
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_trip_active', true);
        await prefs.setInt('active_trip_id', activeTripId);

        if (mounted) {
          setState(() => _isLoading = false);
          // 🚀 ডিভাইস নতুন হলেও ড্রাইভার সরাসরি ম্যাপ ওয়ালা একটিভ ট্রিপ পেজে চলে যাবে
          Navigator.pushReplacementNamed(
            context,
            '/active_trip_page',
            arguments: {'trip_id': activeTripId},
          );
        }
        return;
      }
    } catch (e) {
      print("সার্ভার একটিভ ট্রিপ সিঙ্কিং ত্রুটি: $e");
    }

    // কোনো একটিভ ট্রিপ না থাকলে স্বাভাবিকভাবে আজকের শিডিউল লিস্ট লোড হবে
    _fetchSchedules();
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/driver_login', (route) => false);
    }
  }

  Future<void> _fetchSchedules() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      List<dynamic> data = await _apiService.getSchedules();

      setState(() {
        _schedules = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception:", "");
        _isLoading = false;
      });
    }
  }

  void _handleStartTrip(int busId, int routeId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    Map<String, dynamic> result = await _apiService.startTrip(busId, routeId);

    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      int tripId = int.tryParse(result['trip_id']?.toString() ?? '0') ?? 0;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_trip_active', true);
      await prefs.setInt('active_trip_id', tripId);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/active_trip_page',
          arguments: {'trip_id': tripId},
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'ট্রিপ শুরু করতে সমস্যা হয়েছে'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('স্বাগতম, $_driverName', style: const TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: AppColors.accent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSchedules,
        color: AppColors.accent,
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchSchedules,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('আবার চেষ্টা করুন', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              )
            ],
          ),
        ),
      );
    }

    if (_schedules.isEmpty) {
      return const Center(
        child: Text(
          'আজ আপনার কোনো শিডিউল নেই!',
          style: TextStyle(fontSize: 16, color: AppColors.textGrey, fontWeight: FontWeight.w500),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        return _buildScheduleCard(_schedules[index]);
      },
    );
  }

  Widget _buildScheduleCard(dynamic schedule) {
    // 💡 লারাভেলের জেসন অবজেক্ট সেফলি রিড করা হচ্ছে
    var busData = schedule['bus'];
    var routeData = schedule['route'];

    String busNumber = (busData != null) ? (busData['bus_number']?.toString() ?? '-') : '-';
    String busModel = (busData != null) ? (busData['model_name']?.toString() ?? '') : '';
    String routeName = (routeData != null) ? (routeData['route_name']?.toString() ?? 'অজানা রুট') : 'অজানা রুট';
    String departureTime = schedule['departure_time']?.toString() ?? '--:--';

    // সেফ আইডি পার্সিং (String থেকে Int এরর যেন না আসে)
    int busId = int.tryParse(schedule['bus_id']?.toString() ?? '0') ?? 0;
    int routeId = int.tryParse(schedule['route_id']?.toString() ?? '0') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_bus, color: AppColors.accent, size: 24),
                    const SizedBox(width: 8),
                    Text(busNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    departureTime,
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('রুট: $routeName', style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500)),
            if (busModel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('বাস মডেল: $busModel', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleStartTrip(busId, routeId),
                child: const Text(
                  'ট্রিপ শুরু করুন',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}