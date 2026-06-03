import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'database/lora_database.dart';
import 'providers/lora_provider.dart';
import 'screens/main_shell.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await LoraDatabase.initFfi(); // inisialisasi SQLite FFI sebelum apapun
  runApp(
    ChangeNotifierProvider(
      create: (_) => LoraProvider(),
      child: const LoraApp(),
    ),
  );
}

class LoraApp extends StatelessWidget {
  const LoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoRa Monitor 433MHz',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.blue,
        ),
        fontFamily: 'sans-serif',
      ),
      home: const MainShell(),
    );
  }
}
