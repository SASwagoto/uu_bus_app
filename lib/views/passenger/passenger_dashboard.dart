// lib/views/passenger/passenger_dashboard.dart
import 'package:flutter/material.dart';

class PassengerDashboard extends StatelessWidget {
  const PassengerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('প্যাসেঞ্জার ড্যাশবোর্ড')),
      body: const Center(
        child: Text('প্যাসেঞ্জার ড্যাশবোর্ড (কাজ প্রক্রিয়াধীন...)'),
      ),
    );
  }
}