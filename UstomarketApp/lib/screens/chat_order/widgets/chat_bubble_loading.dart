import 'package:flutter/material.dart';
import '../../../constants.dart';

class ChatBubbleLoading extends StatelessWidget {
  const ChatBubbleLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 60, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
          borderRadius: BorderRadius.circular(16).copyWith(topLeft: const Radius.circular(4)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      ),
    );
  }
}
