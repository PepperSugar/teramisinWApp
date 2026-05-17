import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';

class CompareScreen extends StatelessWidget {
  final String uid;
  const CompareScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: Center(
        child: Text('Compare vs $uid', style: AppTextStyles.heading(20).copyWith(color: AppColors.textSecondary)),
      ),
    );
  }
}
