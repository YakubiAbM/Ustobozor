import 'package:flutter/material.dart';
import '../../../constants.dart';

class ChatBubbleSystem extends StatelessWidget {
  final String text;

  const ChatBubbleSystem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 60, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
          borderRadius: BorderRadius.circular(16).copyWith(
            topLeft: const Radius.circular(4),
          ),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
