import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import 'dio_client.dart';

/// Nature d'un fichier (aligne sur l'enum backend `MediaKind`).
enum MediaKind { image, audio, file }

MediaKind mediaKindFromJson(String? v) {
  switch (v) {
    case 'IMAGE':
      return MediaKind.image;
    case 'AUDIO':
      return MediaKind.audio;
    default:
      return MediaKind.file;
  }
}

String mediaKindToJson(MediaKind k) => switch (k) {
  MediaKind.image => 'IMAGE',
  MediaKind.audio => 'AUDIO',
  MediaKind.file => 'FILE',
};

/// Fichier uploade (reponse de `POST /media`).
class UploadedMedia {
  final String url; // chemin relatif `/media/<nom>`
  final String? fileName;
  final String? contentType;
  final int size;
  final MediaKind kind;

  const UploadedMedia({
    required this.url,
    this.fileName,
    this.contentType,
    this.size = 0,
    this.kind = MediaKind.file,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> j) => UploadedMedia(
    url: j['url'] as String,
    fileName: j['fileName'] as String?,
    contentType: j['contentType'] as String?,
    size: (j['size'] as num?)?.toInt() ?? 0,
    kind: mediaKindFromJson(j['kind'] as String?),
  );
}

/// Upload de fichiers vers le backend (pieces jointes du chat).
class MediaApi {
  final Dio _dio;
  MediaApi(this._dio);

  /// Envoie un fichier depuis son chemin local et renvoie ses metadonnees.
  /// [contentType] force le type MIME (utile pour les vocaux enregistres).
  Future<UploadedMedia> uploadPath(
    String path, {
    String? filename,
    String? contentType,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: filename,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ),
    });
    final res = await _dio.post(ApiConstants.media, data: form);
    return UploadedMedia.fromJson(res.data as Map<String, dynamic>);
  }
}

final mediaApiProvider = Provider<MediaApi>(
  (ref) => MediaApi(ref.read(dioClientProvider)),
);
