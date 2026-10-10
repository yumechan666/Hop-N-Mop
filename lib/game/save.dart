import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

const LEGACY_ROOM_IDS = [
  'bedroom',
  'living',
  'kitchen',
  'bathroom',
  'balcony',
  'art',
  'toy-shop',
  'flower-shop',
];

class SaveData {
  int version = 2;
  int coins = 0;
  int unlocked = 1;
  List<bool> completed = [];
  List<int> stars = [];
  int selectedLevel = 0;
  String skin = 'classic';
  List<String> ownedSkins = ['classic'];
  int bestQuickScore = 0;
  bool tutorialSeen = false;
  bool muted = false;

  SaveData();

  SaveData.defaults() {
    completed = List.filled(ROOMS.length, false);
    stars = List.filled(ROOMS.length, 0);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'coins': coins,
    'unlocked': unlocked,
    'completed': completed,
    'stars': stars,
    'selectedLevel': selectedLevel,
    'skin': skin,
    'ownedSkins': ownedSkins,
    'bestQuickScore': bestQuickScore,
    'tutorialSeen': tutorialSeen,
    'muted': muted,
  };

  static SaveData fromJson(Map<String, dynamic> raw) {
    final base = SaveData.defaults();
    if (raw.isEmpty) return base;

    final source = raw['version'] == 1 ? _migrateLegacy(raw) : raw;
    if (source['version'] != 2) return base;

    base.coins = _max0(source['coins']);
    base.completed = [
      for (int i = 0; i < ROOMS.length; i++)
        (source['completed'] is List && source['completed'].length > i)
            ? source['completed'][i] == true
            : false,
    ];
    base.stars = [
      for (int i = 0; i < ROOMS.length; i++)
        (source['stars'] is List && source['stars'].length > i)
            ? (source['stars'][i] as num).clamp(0, 3).toInt()
            : 0,
    ];

    int firstIncomplete = base.completed.indexOf(false);
    final earnedUnlocks = firstIncomplete == -1
        ? ROOMS.length
        : firstIncomplete + 1;
    // Unlock only the contiguous path that has actually been completed.
    // This keeps later themes locked until every preceding room is finished.
    base.unlocked = earnedUnlocks;

    final validSkins = SKINS.map((s) => s.id).toList();
    final owned = <String>{
      'classic',
      ...((source['ownedSkins'] is List)
          ? List<String>.from(source['ownedSkins'])
          : <String>[]),
    }.where((s) => validSkins.contains(s)).toList();
    base.ownedSkins = owned;
    final requestedSkin = validSkins.contains(source['skin'])
        ? source['skin'] as String
        : 'classic';
    base.skin = owned.contains(requestedSkin) ? requestedSkin : 'classic';

    base.selectedLevel = (source['selectedLevel'] as num? ?? 0)
        .clamp(0, base.unlocked - 1)
        .toInt();
    base.bestQuickScore = _max0(source['bestQuickScore']);
    base.tutorialSeen = source['tutorialSeen'] == true;
    base.muted = source['muted'] == true;
    return base;
  }

  static Map<String, dynamic> _migrateLegacy(Map<String, dynamic> raw) {
    final migrated = SaveData.defaults();
    for (int i = 0; i < LEGACY_ROOM_IDS.length; i++) {
      final nextIndex = ROOMS.indexWhere((e) => e.id == LEGACY_ROOM_IDS[i]);
      if (nextIndex < 0) continue;
      migrated.completed[nextIndex] =
          (raw['completed'] is List && raw['completed'].length > i)
          ? raw['completed'][i] == true
          : false;
      migrated.stars[nextIndex] =
          (raw['stars'] is List && raw['stars'].length > i)
          ? (raw['stars'][i] as num).clamp(0, 3).toInt()
          : 0;
    }
    final legacyIndex = (raw['selectedLevel'] as num? ?? 0).toInt().clamp(
      0,
      LEGACY_ROOM_IDS.length - 1,
    );
    final legacySelectedId = LEGACY_ROOM_IDS[legacyIndex];
    migrated.selectedLevel = ROOMS
        .indexWhere((e) => e.id == legacySelectedId)
        .clamp(0, ROOMS.length - 1);
    migrated.coins = _max0(raw['coins']);
    migrated.skin = raw['skin'] as String? ?? 'classic';
    migrated.ownedSkins = ((raw['ownedSkins'] is List)
        ? List<String>.from(raw['ownedSkins'])
        : <String>['classic']);
    migrated.bestQuickScore = _max0(raw['bestQuickScore']);
    migrated.version = 2;
    return migrated.toJson();
  }

  void reset() {
    version = 2;
    coins = 0;
    unlocked = 1;
    completed = List.filled(ROOMS.length, false);
    stars = List.filled(ROOMS.length, 0);
    selectedLevel = 0;
    skin = 'classic';
    ownedSkins = ['classic'];
    bestQuickScore = 0;
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cleanerroom.save', json.encode(toJson()));
  }

  static Future<SaveData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cleanerroom.save');
    if (raw == null || raw.isEmpty) return SaveData.defaults();
    try {
      return SaveData.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return SaveData.defaults();
    }
  }
}

int _max0(dynamic v) =>
    (v == null ? 0 : (v as num).floor()).clamp(0, 100000000);
