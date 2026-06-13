// lib/views/passenger/passenger_dashboard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  final ApiService _apiService = ApiService();
  List<dynamic> _activeTrips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveTrips();
  }

  Future<void> _loadActiveTrips() async {
    setState(() => _isLoading = true);
    final trips = await _apiService.getActiveTrips();
    setState(() {
      _activeTrips = trips;
      _isLoading = false;
    });
  }

  void _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/passenger_login',
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UU Bus Manage', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text('প্যাসেঞ্জার প্যানেল', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
            onPressed: _loadActiveTrips,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadActiveTrips,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 🌟 টপ ব্যানার ও সময়সূচী বাটন
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'শুভ দিন! আপনার বাসটি খুঁজুন',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'উত্তরা ইউনিভার্সিটি স্মার্ট পরিবহন সেবা',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // 🎯 ফিক্সড সময়সূচী বাটন কার্ড
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: InkWell(
                        onTap: _showScheduleBottomSheet, // সঠিক জায়গায় অনট্যাপ
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.calendar_month_rounded, color: Colors.orange, size: 26),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('আজকের সম্পূর্ণ সময়সূচী', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                    SizedBox(height: 2),
                                    Text('রুট প্ল্যান ও আপ-ডাউন ট্রিপের ডিটেইলস', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🚌 চলমান বাসের সেকশন হেডার
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'চলমান বাসসমূহ (Live)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: 0.3),
                    ),
                    const SizedBox(width: 6),
                    if (_activeTrips.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),

            // 🚫 এম্পটি স্টেট UI
            if (_activeTrips.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                          child: Icon(Icons.bus_alert_rounded, size: 70, color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 20),
                        const Text('এই মুহূর্তে কোনো বাস রানিং নেই', style: TextStyle(fontSize: 16, color: AppColors.textDark, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('লাইভ রানিং ট্রিপ শুরু হলে এখানে দেখতে পাবেন। বাসের সময় জানতে নিচের বাটনটি চাপুন।', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          onPressed: _showScheduleBottomSheet,
                          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          label: const Text('আজকের রুট প্ল্যান চেক করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        )
                      ],
                    ),
                  ),
                ),
              )
            else
            // 📋 লাইভ ট্রিপ কার্ড লিস্ট
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final trip = _activeTrips[index];
                      final busNumber = trip['bus'] != null ? trip['bus']['bus_number'] : 'N/A';
                      final routeName = trip['route'] != null ? trip['route']['route_name'] : 'N/A';
                      final passengers = trip['passenger_count'] ?? 0;

                      final String direction = trip['direction']?.toString() ?? 'up';
                      final String directionText = direction == 'up' ? 'ক্যাম্পাসমুখী' : 'ক্যাম্পাস হতে';
                      final Color directionColor = direction == 'up' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED);

                      // 🎯 ফিক্সড কার্ড উইজেট (যার নিজস্ব margin বা padding হ্যান্ডলিং সেফ)
                      return Card(
                        key: ValueKey(trip['id']),
                        margin: const EdgeInsets.only(bottom: 16), // মার্জিন কন্টেইনার থেকে বের করে কার্ডে আনা হয়েছে
                        elevation: 2,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.white,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.directions_bus_rounded, color: Colors.orange, size: 32),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: directionColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                directionText,
                                                style: TextStyle(color: directionColor, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.airline_seat_recline_normal_rounded, size: 16, color: AppColors.success),
                                                const SizedBox(width: 4),
                                                Text('$passengers জন', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'বাস নম্বর: $busNumber',
                                          style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800, fontSize: 17),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'রুট: $routeName',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // কার্ডের নিচের অ্যাকশন ট্র্যাকিং বাটন
                            InkWell(
                              onTap: () {
                                Navigator.pushNamed(context, '/passenger_track_bus', arguments: {'trip_id': trip['id']});
                              },
                              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.06),
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_rounded, size: 18, color: AppColors.accent),
                                    SizedBox(width: 8),
                                    Text(
                                      'লাইভ ম্যাপে বাস ট্র্যাক করুন',
                                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _activeTrips.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 💡 সময়সূচী বটমশীট
  void _showScheduleBottomSheet() {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(5)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🚌 আজকের সময়সূচী', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const TabBar(
                  labelColor: AppColors.accent,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: 'ক্যাম্পাসমুখী (Up)'),
                    Tab(text: 'ক্যাম্পাস হতে (Down)'),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _apiService.getSchedules(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      }

                      final upTrips = snapshot.data?['up_trips'] ?? [];
                      final downTrips = snapshot.data?['down_trips'] ?? [];

                      return TabBarView(
                        children: [
                          _buildScheduleList(upTrips),
                          _buildScheduleList(downTrips),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleList(List<dynamic> schedules) {
    if (schedules.isEmpty) {
      return const Center(
        child: Text('এই ক্যাটাগরিতে কোনো বাসের শিডিউল নেই।', style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final sch = schedules[index];
        final busNumber = sch['bus'] != null ? sch['bus']['bus_number'] : 'N/A';
        final routeName = sch['route'] != null ? sch['route']['route_name'] : 'N/A';

        String rawTime = sch['departure_time'] ?? '00:00';
        String formattedTime = rawTime.length > 5 ? rawTime.substring(0, 5) : rawTime;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.access_time_filled_rounded, color: Colors.amber, size: 24),
            ),
            title: Text('রুট: $routeName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text('বাস নম্বর: $busNumber', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            trailing: Text(
              formattedTime,
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        );
      },
    );
  }
}