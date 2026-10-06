import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase_providers.dart';

/// Captura, compresión y subida de fotografías.
///
/// * Comprime a JPEG (máx. ~1600 px, calidad 75) para ahorrar datos móviles.
/// * La compresión NO conserva metadatos EXIF (elimina la ubicación GPS
///   incrustada y datos del dispositivo) → protección de privacidad.
/// * Guarda una copia en el almacenamiento de la app para que sobreviva si el
///   reporte queda en la cola sin conexión.
class PhotoService {
  PhotoService(this._client);
  final SupabaseClient _client;
  final _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2400, maxHeight: 2400);
    if (picked == null) return null;
    return _compressAndPersist(picked.path);
  }

  Future<File> _compressAndPersist(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'report_photos'));
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final target = p.join(photosDir.path, 'photo_${DateTime.now().microsecondsSinceEpoch}.jpg');

    final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: 1600,
      minHeight: 1600,
      quality: 75,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final file = File(target);
    if (bytes != null) {
      await file.writeAsBytes(bytes, flush: true);
    } else {
      await File(sourcePath).copy(target);
    }
    return file;
  }

  /// Sube la foto a `report-photos/<userId>/<clientUuid>.jpg` y devuelve
  /// la ruta y la URL pública. `upsert` permite reintentos idempotentes.
  Future<({String path, String url})> upload({
    required File file,
    required String userId,
    required String clientUuid,
  }) async {
    final storagePath = '$userId/$clientUuid.jpg';
    await _client.storage.from(reportPhotosBucket).uploadBinary(
          storagePath,
          await file.readAsBytes(),
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final url = _client.storage.from(reportPhotosBucket).getPublicUrl(storagePath);
    return (path: storagePath, url: url);
  }

  Future<void> deleteLocal(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

final photoServiceProvider =
    Provider<PhotoService>((ref) => PhotoService(ref.watch(supabaseProvider)));
