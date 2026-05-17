import 'package:flutter/material.dart';

class GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const GreenButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, child: Text(label));
  }
}
