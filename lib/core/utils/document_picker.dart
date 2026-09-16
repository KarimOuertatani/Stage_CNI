import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Document choisi via le sélecteur natif.
class PickedDocument {
  final String path;
  final String name;
  final int size;

  const PickedDocument({required this.path, required this.name, this.size = 0});
}

/// Sélecteur de document natif (Storage Access Framework côté Android).
///
/// Implémenté en Kotlin dans `MainActivity` plutôt qu'avec le plugin
/// `file_picker` (incompatible avec l'Android Gradle Plugin 9). Renvoie `null`
/// si l'utilisateur annule.
///
/// iOS : non implémenté pour l'instant ([DocumentPickerUnsupported] est levé) —
/// les photos y restent disponibles via la galerie.
class DocumentPicker {
  static const _channel = MethodChannel('fitforge/document_picker');

  static Future<PickedDocument?> pick() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'pickDocument',
      );
      if (res == null) return null;
      return PickedDocument(
        path: res['path'] as String,
        name: (res['name'] as String?) ?? 'document',
        size: (res['size'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      // Le canal natif n'est pas enregistré : sur Android c'est presque
      // toujours un build obsolète (le code Kotlin a changé) ; sur iOS/web le
      // sélecteur n'est pas encore implémenté.
      if (!kIsWeb && Platform.isAndroid) {
        throw const DocumentPickerUnsupported(
          'Fermez et relancez l\'application (build à réinstaller) pour activer l\'envoi de documents.',
        );
      }
      throw const DocumentPickerUnsupported(
        'L\'envoi de documents n\'est pas encore disponible sur cette plateforme.',
      );
    }
  }
}

/// Levée quand le sélecteur natif n'est pas disponible (build obsolète, iOS…).
class DocumentPickerUnsupported implements Exception {
  final String message;
  const DocumentPickerUnsupported([
    this.message =
        'L\'envoi de documents n\'est pas disponible sur cette plateforme.',
  ]);
  @override
  String toString() => message;
}
