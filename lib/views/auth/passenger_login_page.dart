// lib/views/auth/passenger_login_page.dart
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class PassengerLoginPage extends StatefulWidget {
  const PassengerLoginPage({super.key});

  @override
  State<PassengerLoginPage> createState() => _PassengerLoginPageState();
}

class _PassengerLoginPageState extends State<PassengerLoginPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.login(
      _emailController.text.trim(),
      _passwordController.text,
      'passenger', // এই প্যানেলে শুধু প্যাসেঞ্জার ঢুকতে পারবে
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/passenger_dashboard');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.directions_bus, size: 80, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'UU Bus Manage',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const Text(
                  'প্যাসেঞ্জার লগইন',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textGrey),
                ),
                const SizedBox(height: 32),

                // ইমেইল ইনপুট
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'ইউনিভার্সিটি মেইল',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'মেইল দিন';
                    if (!value.endsWith('@uttarauniversity.edu.bd')) {
                      return 'উত্তরা ইউনিভার্সিটির অফিসিয়াল মেইল ব্যবহার করুন';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // পাসওয়ার্ড ইনপুট
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'পাসওয়ার্ড',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'পাসওয়ার্ড দিন' : null,
                ),
                const SizedBox(height: 24),

                // লগইন বাটন
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('লগইন করুন', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                // রেজিস্ট্রেশন লিঙ্ক
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/passenger_register'),
                  child: const Text('নতুন অ্যাকাউন্ট তৈরি করুন (Register)', style: TextStyle(color: AppColors.accent)),
                ),

                const Divider(height: 40),

                // ড্রাইভার প্যানেলে যাওয়ার বাটন
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/driver_login'),
                  icon: const Icon(Icons.drive_eta, color: AppColors.primary),
                  label: const Text('ড্রাইভার প্যানেলে যান', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}