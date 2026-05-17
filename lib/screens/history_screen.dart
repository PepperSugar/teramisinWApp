import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Center(
        child: Text('History', style: AppTextStyles.heading(20).copyWith(color: AppColors.textSecondary)),
      ),
    );
  }
}
