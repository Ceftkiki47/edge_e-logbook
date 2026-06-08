import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.description = 'Halaman ini akan segera tersedia.',
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppTopbar(title: title),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            SizedBox(height: 6),
            Text(description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                )),
          ]),
        ),
      ),
    ]);
  }
}
