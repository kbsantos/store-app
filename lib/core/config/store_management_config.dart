import 'package:flutter_dotenv/flutter_dotenv.dart';

class StoreManagementConfig {
  static String get url => dotenv.env['SUPABASE_URL']?.trim() ?? '';
  static String get publishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim().isNotEmpty == true
          ? dotenv.env['SUPABASE_PUBLISHABLE_KEY']!.trim()
          : dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
