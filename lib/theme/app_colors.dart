import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDarkMode = false;

  static Color get background  => isDarkMode ? const Color(0xFF0F1117) : const Color(0xFFF1F5F9);
  static Color get surface     => isDarkMode ? const Color(0xFF1A1D27) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt  => isDarkMode ? const Color(0xFF13151F) : const Color(0xFFF8FAFC);
  static Color get border      => isDarkMode ? const Color(0xFF2A2D3E) : const Color(0xFFE2E8F0);

  static Color get textPrimary   => isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  static Color get textSecondary => isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get textMuted     => isDarkMode ? const Color(0xFF4A5568) : const Color(0xFF64748B);

  static Color get blue    => const Color(0xFF3B82F6);
  static Color get blueBg  => isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);

  static Color get online    => const Color(0xFF22C55E);
  static Color get onlineBg  => isDarkMode ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
  static Color get onlineSub => isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);

  static Color get amber   => const Color(0xFFF59E0B);
  static Color get amberBg => isDarkMode ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);

  static Color get purple   => const Color(0xFFA855F7);
  static Color get purpleBg => isDarkMode ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF);

  static Color get danger     => const Color(0xFFEF4444);
  static Color get dangerText => const Color(0xFFEF4444);
  static Color get dangerBg   => isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);

  static Color get warning   => const Color(0xFFF59E0B);
  static Color get warningBg => isDarkMode ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);

  // Tag colors
  static Color get tagRxBg   => isDarkMode ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
  static Color get tagRxText => isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  static Color get tagSysBg  => isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);
  static Color get tagSysText => isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get tagErrBg  => isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
  static Color get tagErrText => isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  static Color get sidebarBg            => const Color(0xFF13151F);
  static Color get sidebarActive        => const Color(0xFF1E3A5F);
  static Color get sidebarTextPrimary   => const Color(0xFFE2E8F0);
  static Color get sidebarTextSecondary => const Color(0xFF94A3B8);
  static Color get sidebarTextMuted     => const Color(0xFF4A5568);
  static Color get sidebarBorder        => const Color(0xFF2A2D3E);
}
