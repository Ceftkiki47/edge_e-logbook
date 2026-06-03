import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ConfirmLevel { warning, danger }

/// Dialog konfirmasi yang konsisten untuk semua aksi hapus.
/// Kembalikan `true` jika user klik konfirmasi, `false` atau `null` jika batal.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel  = 'Batal',
  ConfirmLevel level  = ConfirmLevel.danger,
  Widget? detail,          // widget tambahan di bawah message (opsional)
  String? countLabel,      // contoh: "124 paket akan dihapus permanen"
}) async {
  final confirmColor = level == ConfirmLevel.danger ? AppColors.danger : AppColors.amber;
  final confirmBg    = level == ConfirmLevel.danger ? AppColors.dangerBg : AppColors.amberBg;
  final iconData     = level == ConfirmLevel.danger
      ? Icons.delete_forever_outlined
      : Icons.warning_amber_outlined;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon + Title ─────────────────────────────────────────────
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: confirmBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, size: 20, color: confirmColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Message ───────────────────────────────────────────────────
              Text(message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  )),

              // ── Count badge ───────────────────────────────────────────────
              if (countLabel != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: confirmBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: confirmColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 13, color: confirmColor),
                    const SizedBox(width: 7),
                    Text(countLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: confirmColor,
                          fontWeight: FontWeight.w600,
                        )),
                  ]),
                ),
              ],

              // ── Extra detail widget ───────────────────────────────────────
              if (detail != null) ...[
                const SizedBox(height: 12),
                detail,
              ],

              const SizedBox(height: 24),

              // ── Tombol ────────────────────────────────────────────────────
              Row(children: [
                // Batal
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(cancelLabel,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                // Konfirmasi
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirmLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );

  return result ?? false;
}
