import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';

class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Text('Profile: $uid', style: AppTextStyles.heading(20).copyWith(color: AppColors.textSecondary)),
      ),
    );
  }
}
