import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'data/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    throw StateError(
      'Missing Supabase config. Run with --dart-define-from-file=env.json '
      '(copy env.example.json).',
    );
  }
  await initSupabase();
  runApp(const ProviderScope(child: TorneoFlashApp()));
}
