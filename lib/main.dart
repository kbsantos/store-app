import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/store_management_config.dart';
import 'core/auth/auth_gate.dart';
import 'core/theme/store_management_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  if (!StoreManagementConfig.isConfigured) {
    runApp(const _ConfigurationErrorApp());
    return;
  }
  await Supabase.initialize(
    url: StoreManagementConfig.url,
    publishableKey: StoreManagementConfig.publishableKey,
  );
  runApp(const BiggerBrewStoreManagementApp());
}

class BiggerBrewStoreManagementApp extends StatelessWidget {
  const BiggerBrewStoreManagementApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bigger Brew Store Management',
        theme: storeManagementTheme(),
        home: const StoreManagementAuthGate(),
      );
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Supabase is not configured. Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to .env.', style: Theme.of(context).textTheme.titleMedium))),
        ),
      );
}
