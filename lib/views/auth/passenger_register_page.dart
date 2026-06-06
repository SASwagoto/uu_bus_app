// lib/views/auth/passenger_register_page.dart
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class PassengerRegisterPage extends StatefulWidget {
  const PassengerRegisterPage({super.key});

  @override
  State<PassengerRegisterPage> createState() => _PassengerRegisterPageState();
}

class _PassengerRegisterPageState extends State<PassengerRegisterPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.registerPassenger(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      studentId: _studentIdController.text.trim().isEmpty ? null : _studentIdController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('রেজিস্ট্রেশন সফল হয়েছে!'), backgroundColor: AppColors.success),
        );
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
      appBar: AppBar(title: const Text('প্যাসেঞ্জার রেজিস্ট্রেশন')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'নতুন অ্যাকাউন্ট তৈরি করুন',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // নাম
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'পূর্ণ নাম', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'আপনার নাম দিন' : null,
                ),
                const SizedBox(height: 16),

                // ইউনিভার্সিটি মেইল ভ্যালিডেশন
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'ইউনিভার্সিটি মেইল আইডি',
                      hintText: 'example@uttarauniversity.edu.bd',
                      prefixIcon: Icon(Icons.school),
                      border: OutlineInputBorder()
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'মেইল আইডি দিন';
                    if (!value.endsWith('@uttarauniversity.edu.bd')) {
                      return 'শুধুমাত্র @uttarauniversity.edu.bd মেইল গ্রহণযোগ্য';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // স্টুডেন্ট আইডি (অপশনাল)
                TextFormField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'স্টুডেন্ট আইডি (অপশনাল)',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 16),

                // পাসওয়ার্ড
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'পাসওয়ার্ড', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'পাসওয়ার্ড দিন';
                    if (value.length < 6) return 'পাসওয়ার্ড কমপক্ষে ৬ ডিজিটের হতে হবে';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // সাবমিট বাটন
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('রেজিস্ট্রেশন সম্পন্ন করুন', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}