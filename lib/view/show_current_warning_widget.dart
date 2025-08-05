import 'package:flutter/material.dart';

class ShowCurrentWarning extends StatelessWidget {
  const ShowCurrentWarning({super.key, required this.message, this.onPressed});

  final String message;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(onPressed: onPressed, child: Text(message)),
    );
  }
}
