import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Center(
        child: Text('Progress', style: AppTextStyles.heading(20).copyWith(color: AppColors.textSecondary)),
      ),
    );
  }
}
