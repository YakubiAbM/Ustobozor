import 'package:flutter/material.dart';
import '../../../constants.dart';

class ChatBubbleUser extends StatelessWidget {
  final String text;

  const ChatBubbleUser({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 60, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16).copyWith(
            topRight: const Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.accentContrastText, fontSize: 15),
        ),
      ),
    );
  }
}
