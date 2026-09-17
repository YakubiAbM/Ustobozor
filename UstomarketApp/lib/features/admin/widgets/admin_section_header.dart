import 'package:flutter/material.dart';

import '../constants.dart';

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
    this.trailing,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenPadding,
        8,
        AppLayout.screenPadding,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (action != null && actionLabel != null)
            TextButton(
              onPressed: action,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
