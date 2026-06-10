import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';

class AppTopbar extends StatefulWidget {
  final String title;
  const AppTopbar({super.key, required this.title});

  @override
  State<AppTopbar> createState() => _AppTopbarState();
}

class _AppTopbarState extends State<AppTopbar> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm:ss');
    final dateFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        if (Navigator.canPop(context)) ...[
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
            ),
          ),
        ],
        Text(widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
        const Spacer(),

        // Status koneksi
        Consumer<LoraProvider>(
          builder: (_, prov, __) {
            final connected = prov.isConnected;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: connected ? AppColors.onlineBg : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: connected ? AppColors.online : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? AppColors.online : AppColors.textMuted,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  connected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppColors.onlineSub : AppColors.textMuted,
                  ),
                ),
              ]),
            );
          },
        ),

        SizedBox(width: 16),

        // Jam + tanggal
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeFmt.format(_now),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                )),
            Text('${dateFmt.format(_now)} WIB',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                )),
          ],
        ),
      ]),
    );
  }
}
