import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import 'frames.dart';

class AssetPack {
  final Map<String, String> manifest;
  final Map<String, ui.Image> images = {};
  final Map<String, Sheet> sheets = {};

  AssetPack(this.manifest);

  Future<void> ensure(List<String> keys) async {
    final pending = Set<String>.from(
      keys,
    ).where((key) => !images.containsKey(key));
    await Future.wait(
      pending.map((key) async {
        final path = manifest[key];
        if (path == null) throw Exception('Unknown asset key: $key');
        final fileName = path.split('/').last;
        final bytes = await rootBundle.load('assets/images/$fileName');
        final image = await decodeImageFromList(bytes.buffer.asUint8List());
        images[key] = image;
        if (key.endsWith('_ATLAS') || key.endsWith('_SHEET')) {
          try {
            sheets[key] = await loadSheet('assets/json/$key.frames.json');
          } catch (_) {
            // Sheet metadata missing; frames unavailable for this key.
          }
        }
      }),
    );
  }

  static Future<Map<String, String>> loadManifest() async {
    final text = await rootBundle.loadString('assets/json/assets.json');
    final map = json.decode(text) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }
}

Future<ui.Image> decodeImageFromList(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
