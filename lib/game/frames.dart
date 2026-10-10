import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

class Frame {
  final String name;
  final Rect source;
  final Rect content;
  final Offset anchor;

  Frame(this.name, this.source, this.content, this.anchor);
}

class SpriteAnimation {
  final String name;
  final List<Frame> frames;

  SpriteAnimation(this.name, this.frames);
}

class Sheet {
  final String image;
  final List<Frame> frames;
  final List<SpriteAnimation> animations;

  Sheet(this.image, this.frames, this.animations);
}

Frame? frameNamed(Sheet? sheet, String name) {
  if (sheet == null) return null;
  for (final f in sheet.frames) {
    if (f.name == name) return f;
  }
  for (final a in sheet.animations) {
    for (final f in a.frames) {
      if (f.name == name) return f;
    }
  }
  return null;
}

SpriteAnimation? animationNamed(Sheet? sheet, String name) {
  if (sheet == null) return null;
  for (final a in sheet.animations) {
    if (a.name == name) return a;
  }
  return null;
}

Future<Sheet> loadSheet(String jsonAssetPath) async {
  final text = await rootBundle.loadString(jsonAssetPath);
  final map = json.decode(text) as Map<String, dynamic>;
  final image = map['image'] as String;
  final framesRaw = map['frames'] as List;
  final frames = framesRaw.map((e) {
    final m = e as Map<String, dynamic>;
    return Frame(m['name'] as String, _rect(m['source']), _rect(m['content']), _offset(m['anchor']));
  }).toList();
  final animsRaw = (map['animations'] as List?) ?? <dynamic>[];
  final animations = animsRaw.map((e) {
    final m = e as Map<String, dynamic>;
    final fr = (m['frames'] as List).map((fe) {
      final fm = fe as Map<String, dynamic>;
      return Frame(fm['name'] as String, _rect(fm['source']), _rect(fm['content']), _offset(fm['anchor']));
    }).toList();
    return SpriteAnimation(m['name'] as String, fr);
  }).toList();
  return Sheet(image, frames, animations);
}

Rect _rect(Map<String, dynamic> m) =>
    Rect.fromLTWH(_n(m['x']), _n(m['y']), _n(m['w']), _n(m['h']));

Offset _offset(Map<String, dynamic> m) => Offset(_n(m['x']), _n(m['y']));

double _n(dynamic v) => (v as num).toDouble();
