import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';

// ── Status Card ───────────────────────────────────────────────────────────────
class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoraProvider>(
      builder: (_, prov, __) {
        final connected = prov.isConnected;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.onlineBg : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    connected ? Icons.link : Icons.link_off,
                    size: 18,
                    color: connected ? AppColors.online : AppColors.textMuted,
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status Perangkat',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(
                      connected ? 'Terhubung' : 'Terputus',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: connected ? AppColors.online : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? AppColors.online : AppColors.textMuted,
                    boxShadow: connected
                        ? [BoxShadow(color: AppColors.online.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                ),
              ]),
              SizedBox(height: 14),
              _infoRow('Port', prov.selectedPort ?? '—'),
              SizedBox(height: 6),
              _infoRow('Baud Rate', '${prov.baudRate} bps'),
              SizedBox(height: 6),
              _infoRow('Frekuensi', '433 MHz'),
              SizedBox(height: 14),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amberBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline, size: 11, color: AppColors.amber),
                  SizedBox(width: 5),
                  Text('Mode Terima Saja — Pengiriman Dinonaktifkan',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber,
                      )),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              )),
        ],
      );
}

// ── Signal Card ───────────────────────────────────────────────────────────────
class SignalCard extends StatelessWidget {
  const SignalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoraProvider>(
      builder: (_, prov, __) {
        final rssi = prov.lastRssi;
        final snr  = prov.lastSnr;
        final rssiPct = rssi != null ? ((rssi + 120) / 90).clamp(0.0, 1.0) : 0.0;
        final snrPct  = snr  != null ? ((snr  + 20)  / 30).clamp(0.0, 1.0) : 0.0;

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.signal_cellular_alt, size: 16, color: AppColors.blue),
                SizedBox(width: 8),
                Text('Kualitas Sinyal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
              ]),
              SizedBox(height: 16),
              _signalRow('RSSI', rssi != null ? '$rssi dBm' : '—', rssiPct, AppColors.blue),
              SizedBox(height: 12),
              _signalRow('SNR',  snr  != null ? '${snr.toStringAsFixed(1)} dB' : '—', snrPct, AppColors.onlineSub),
              const Spacer(),
              if (rssi == null)
                Text('Menunggu data sinyal...',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        );
      },
    );
  }

  Widget _signalRow(String label, String value, double pct, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            Text(value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'monospace',
                )),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]);
}

// ── Error Count Card ──────────────────────────────────────────────────────────
class ErrorCountCard extends StatelessWidget {
  const ErrorCountCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoraProvider>(
      builder: (_, prov, __) {
        final errCount = prov.errCount;
        return _Card(
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: errCount > 0 ? AppColors.dangerBg : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_outline,
                  size: 18,
                  color: errCount > 0 ? AppColors.danger : AppColors.textMuted),
            ),
            SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Error',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('$errCount',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: errCount > 0 ? AppColors.danger : AppColors.textMuted,
                  )),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Mini Stat Card ────────────────────────────────────────────────────────────
class MiniStatCard extends StatelessWidget {
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const MiniStatCard({
    super.key,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
          Text(sub, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

// ── Shared card container ─────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}
