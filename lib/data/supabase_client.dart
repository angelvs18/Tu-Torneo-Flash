import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/env.dart';

part 'supabase_client.g.dart';

Future<void> initSupabase() => Supabase.initialize(
  url: Env.supabaseUrl,
  publishableKey: Env.supabasePublishableKey,
);

/// Only repositories should read this provider; widgets never touch Supabase.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;
