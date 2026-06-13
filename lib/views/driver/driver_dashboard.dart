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

  // 💡 ডাটা স্ট্রাকচার পরিবর্তন করে ম্যাপ এর ভেতর ২টি আলাদা লিস্ট রাখা হলো
  List<dynamic> _upSchedules = [];
  List<dynamic> _downSchedules = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDriverName();
    _checkActiveTripAndFetchSchedules();
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

      Map<String, dynamic> activeTripStatus = await _apiService.getCurrentDriverActiveTrip();

      if (activeTripStatus['has_active_trip'] == true && activeTripStatus['trip'] != null) {
        var tripData = activeTripStatus['trip'];
        int activeTripId = int.tryParse(tripData['id']?.toString() ?? '0') ?? 0;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_trip_active', true);
        await prefs.setInt('active_trip_id', activeTripId);

        if (mounted) {
          setState(() => _isLoading = false);
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

      // 💡 এপিআই সার্ভিস থেকে এখন Map ডাটা আসবে
      Map<String, dynamic> data = await _apiService.getSchedules();

      setState(() {
        _upSchedules = data['up_trips'] ?? [];
        _downSchedules = data['down_trips'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception:", "");
        _isLoading = false;
      });
    }
  }

  // 💡 রিকুয়েস্টে direction (up/down) প্যারামিটার যুক্ত করা হলো
  void _handleStartTrip(int busId, int routeId, String direction) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    // 💡 আপনার apiService.startTrip মেথডে ৩টি আর্গুমেন্ট পাস করতে হবে
    Map<String, dynamic> result = await _apiService.startTrip(busId, routeId, direction);

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
            content: Text(result['message'] ?? 'ট্রিপ শুরু করতে সমস্যা হয়েছে'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 ২টা ট্যাবের জন্য DefaultTabController অ্যাড করা হলো
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text('স্বাগতম, $_driverName', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            ),
            const SizedBox(width: 8),
          ],
          // 💡 ড্রাইভারের জন্য সুন্দর ট্যাব বার হেডার
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.login_rounded), text: 'ক্যাম্পাসমুখী (Up)'),
              Tab(icon: Icon(Icons.logout_rounded), text: 'ক্যাম্পাস হতে (Down)'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _fetchSchedules,
          color: AppColors.accent,
          child: _buildBodyContent(),
        ),
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

    // 💡 ট্যাব ভিউ রিটার্ন করা হচ্ছে যা সুইপ করলে ডাইনামিক লিস্ট দেখাবে
    return TabBarView(
      children: [
        _buildScheduleListView(_upSchedules, 'up'),
        _buildScheduleListView(_downSchedules, 'down'),
      ],
    );
  }

  // 💡 কোড রিইউজেবিলিটি বাড়ানোর জন্য জেনেরিক লিস্ট ভিউ মেথড
  Widget _buildScheduleListView(List<dynamic> schedules, String direction) {
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              direction == 'up' ? 'আজ সকালে কোনো Up শিডিউল নেই!' : 'আজ বিকেলে কোনো Down শিডিউল নেই!',
              style: const TextStyle(fontSize: 15, color: AppColors.textGrey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        return _buildScheduleCard(schedules[index], direction);
      },
    );
  }

  // 💡 কার্ডের ভেতর direction পাস করা হলো যেন বাটনে ক্লিক করলে সঠিক ডিরেকশন ট্রিপ শুরু হয়
  Widget _buildScheduleCard(dynamic schedule, String direction) {
    var busData = schedule['bus'];
    var routeData = schedule['route'];

    String busNumber = (busData != null) ? (busData['bus_number']?.toString() ?? '-') : '-';
    String busModel = (busData != null) ? (busData['model_name']?.toString() ?? '') : '';
    String routeName = (routeData != null) ? (routeData['route_name']?.toString() ?? 'অজানা রুট') : 'অজানা রুট';
    String departureTime = schedule['departure_time']?.toString() ?? '--:--';

    // ফর্ম্যাটকে ৫ ক্যারেক্টারে রাখা (যেমন: ১২:৩০:০০ থেকে ১২:৩০ করা)
    if (departureTime.length > 5) {
      departureTime = departureTime.substring(0, 5);
    }

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
                  backgroundColor: direction == 'up' ? Colors.blue[700] : Colors.purple[700], // ডিরেকশন অনুযায়ী আলাদা ভাইব
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                // 💡 এখানে direction পাস হচ্ছে ব্যাকএন্ডের জন্য
                onPressed: () => _handleStartTrip(busId, routeId, direction),
                child: Text(
                  direction == 'up' ? 'Up ট্রিপ শুরু করুন' : 'Down ট্রিপ শুরু করুন',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}