import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente Supabase compartido (inicializado en main.dart).
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Nombre del bucket de fotografías (ver migración 5).
const reportPhotosBucket = 'report-photos';
