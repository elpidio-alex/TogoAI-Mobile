import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Locales supportées : fr | en | ewe (comme le web).
const supportedLocales = [
  Locale('fr'),
  Locale('en'),
  Locale('ewe'),
];

final localeCodeProvider = StateProvider<String>((ref) => 'fr');

Future<void> persistLocale(WidgetRef ref, BuildContext context, String code) async {
  ref.read(localeCodeProvider.notifier).state = code;
  await context.setLocale(Locale(code));
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    await Supabase.instance.client
        .from('users')
        .update({'language': code}).eq('id', user.id);
  }
}
