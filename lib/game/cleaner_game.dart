import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'asset_pack.dart';
import 'audio.dart';
import 'data.dart';
import 'frames.dart';
import 'save.dart';

class TargetHit {
  final String id;
  final Rect rect;
  TargetHit(this.id, this.rect);
}

class GameController extends ChangeNotifier {
  SaveData save;
  String roomName = '';
  int completed = 0;
  int total = 0;
  double progress = 0;
  int coins = 0;
  bool quick = false;
  bool timerStarted = false;
  double timeLeft = 0;
  double? elapsed;
  bool loading = true;
  String loadingMessage = 'Bunny is gathering baskets…';
  String? toast;
  String overlay = 'none';
  Map<String, dynamic> overlayData = {};
  List<TargetDef>? targets;
  List<TargetHit> targetRects = [];

  GameController(this.save);

  void refreshHud() => notifyListeners();
}

class Particle {
  double x, y, vx, vy, life, maxLife, size, spin;
  Color color;
  Particle(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.life,
    this.maxLife,
    this.size,
    this.spin,
    this.color,
  );
}

class RoomRuntimeState {
  final Room room;
  final int levelIndex;
  final List<RoomItem> items;
  String? draggedId;
  CareDef? activeCare;
  int careIndex = -1;
  int careCompleted = 0;
  double careProgress = 0;
  bool plantBloom = false;
  double progress = 0;
  final bool quick;
  int? timerStartMs;
  double elapsed;
  int timeLimitMs = 0;
  int timeLeftMs = 0;
  bool timeUp = false;
  bool paused;
  int? pauseBeganMs;
  bool completing;
  int completionStartedMs;
  int bunnyCheerUntilMs;
  int bunnyUpsetUntilMs;
  String skin;

  RoomRuntimeState({
    required this.room,
    required this.levelIndex,
    required this.items,
    required this.quick,
    required this.skin,
  }) : elapsed = 0,
       timeLimitMs = ((room.quick?.silver ?? 90) * 1000).round(),
       timeLeftMs = ((room.quick?.silver ?? 90) * 1000).round(),
       paused = false,
       completing = false,
       completionStartedMs = 0,
       bunnyCheerUntilMs = 0,
       bunnyUpsetUntilMs = 0;
}

class CleanerGame extends Game {
  final GameController controller;
  AssetPack? pack;
  RoomRuntimeState? state;

  final Map<String, Rect> _itemRects = {};
  Rect? _careRect;
  final List<Particle> _particles = [];

  String? _mode;
  Offset _lastPoint = Offset.zero;
  int _lastSwipeSoundMs = 0;
  int _roomLoadToken = 0;
  int _now = 0;
  int _lastShownSec = -1;
  int _completionToken = 0;
  final Random _random = Random();
  String _albumReturn = 'menu';
  String _tutorialReturn = 'menu';

  AudioEngine? _audio;

  double wipeDistance;
  double itemScale;
  int sparkleCount;
  double sfxVolume;
  double itemOpacity;

  CleanerGame(
    this.controller, {
    this.wipeDistance = 260,
    this.itemScale = 1,
    this.sparkleCount = 16,
    this.sfxVolume = 0.32,
    this.itemOpacity = 0.55,
  });

  Future<void> _loadTweaks() async {
    try {
      final text = await rootBundle.loadString('assets/json/tweaks.json');
      final map = json.decode(text) as Map<String, dynamic>;
      double v(String k, double d) =>
          (map[k]?['value'] as num?)?.toDouble() ?? d;
      wipeDistance = v('wipeDistance', 260);
      itemScale = v('itemScale', 1);
      sparkleCount = v('sparkleCount', 16).round();
      sfxVolume = v('sfxVolume', 0.32);
      itemOpacity = v('itemOpacity', 0.55).clamp(0.2, 1);
    } catch (_) {
      // Keep defaults if the file is missing.
    }
  }

  @override
  Future<void> onLoad() async {
    controller.save = await SaveData.load();
    final manifest = await AssetPack.loadManifest();
    pack = AssetPack(manifest);
    await _loadTweaks();
    final initialIndex = controller.save.selectedLevel.clamp(
      0,
      (controller.save.unlocked - 1).clamp(0, ROOMS.length - 1),
    );
    await pack!.ensure(requiredAssetsFor(ROOMS[initialIndex]));
    await pack!.ensure(albumAssets());
    state = createRoomState(initialIndex, false);
    controller.save.selectedLevel = initialIndex;
    await controller.save.persist();
    _audio = AudioEngine();
    _audio!.volume = sfxVolume.clamp(0, 1);
    _audio!.bgmVolume = (sfxVolume * 0.5).clamp(0, 1);
    _audio!.muted = controller.save.muted;
    controller.loading = false;
    controller.overlay = controller.save.tutorialSeen ? 'menu' : 'tutorial';
    controller.refreshHud();
  }

  void _setWorldArea(int levelIndex) {
    const worldBgm = <String, int>{
      'HOME': 1,
      'SCHOOL': 2,
      'SHOP': 3,
      'HOTEL': 4,
      'TOWN': 5,
    };
    final world = ROOMS[levelIndex].world;
    _audio?.setArea((worldBgm[world] ?? 1) - 1);
  }

  void playSfx(String name) {
    if (_audio == null) {
      _audio = AudioEngine();
      _audio!.volume = sfxVolume.clamp(0, 1);
      _audio!.bgmVolume = (sfxVolume * 0.5).clamp(0, 1);
      _audio!.muted = controller.save.muted;
    }
    _audio!.unlock();
    switch (name) {
      case 'place':
        _audio!.place();
      case 'hit':
        _audio!.hit();
      case 'jump':
        _audio!.jump();
      case 'win':
        _audio!.win();
      case 'swipe':
        _audio!.swipe();
      case 'coin':
        _audio!.coin();
      case 'click':
        _audio!.click();
      case 'unlock':
        _audio!.unlockSfx();
    }
  }

  List<String> requiredAssetsFor(Room room, [String? skinId]) {
    final skin = skinId ?? controller.save.skin;
    return [
      room.assetKey,
      'BUNNY_SHEET',
      skinSheet(skin),
      ...room.items.map((e) => e.atlas),
      ...room.targets.map((e) => e.atlas),
      ...room.care.map((e) => e.atlas),
    ];
  }

  List<String> albumAssets() => [
    ...ROOMS.map((r) => r.assetKey),
    'BUNNY_SHEET',
    ...SKINS.map((s) => s.sheet).toSet(),
  ];

  RoomRuntimeState createRoomState(int levelIndex, bool quick) {
    final room = ROOMS[levelIndex];
    return RoomRuntimeState(
      room: room,
      levelIndex: levelIndex,
      items: freshItems(room),
      quick: quick,
      skin: controller.save.skin,
    );
  }

  void enterRoom() {
    final s = state!;
    _setWorldArea(s.levelIndex);
    controller.loading = false;
    controller.loadingMessage = 'Bunny is gathering baskets…';
    controller.targets = roomTargets(s.room);
    controller.roomName = s.room.shortName;
    updateProgress();
    controller.overlay = 'none';
    controller.overlayData = {};
    controller.quick = s.quick;
    controller.timerStarted = false;
    controller.timeLeft = 0;
    controller.elapsed = 0;
    final msg = s.quick
        ? 'Quick Clean · timer starts on your first move'
        : s.levelIndex == 0
        ? 'Sort every object · timer starts on your first move'
        : '${s.room.world} · Beat the clock to clean this room';
    showToast(msg, 2400);
    controller.refreshHud();
  }

  Future<void> startRoom(int levelIndex, [bool quick = false]) async {
    final safe = levelIndex.clamp(
      0,
      (controller.save.unlocked - 1).clamp(0, ROOMS.length - 1),
    );
    controller.overlay = 'none';
    controller.loading = true;
    controller.loadingMessage = 'Bunny is opening the next room…';
    controller.refreshHud();
    if (state != null) state!.paused = true;
    final token = ++_roomLoadToken;
    try {
      await pack!.ensure(requiredAssetsFor(ROOMS[safe]));
    } catch (_) {
      if (token == _roomLoadToken) {
        controller.loadingMessage = 'The room art did not arrive.';
        controller.refreshHud();
      }
      return;
    }
    if (token != _roomLoadToken) return;
    state = createRoomState(safe, quick);
    _lastShownSec = -1;
    enterRoom();
  }

  void updateProgress() {
    final s = state;
    if (s == null) return;
    final done = s.items.where((e) => e.placed).length + s.careCompleted;
    final total = s.items.length + s.room.care.length;
    s.progress = total == 0 ? 1 : done / total;
    controller.completed = done;
    controller.total = total;
    controller.progress = s.progress;
    controller.coins = controller.save.coins;
    controller.refreshHud();
  }

  void showToast(String message, [int durationMs = 1500]) {
    controller.toast = message;
    controller.refreshHud();
    Timer(Duration(milliseconds: durationMs), () {
      if (controller.toast == message) {
        controller.toast = null;
        controller.refreshHud();
      }
    });
  }

  void startTimerOnAction() {
    final s = state;
    if (s == null) return;
    if (s.quick && s.timerStartMs == null) {
      s.timerStartMs = _now;
      s.elapsed = 0;
      controller.elapsed = 0;
      controller.quick = true;
      controller.refreshHud();
    } else if (!s.quick && s.timerStartMs == null) {
      s.timerStartMs = _now;
      s.timeLeftMs = s.timeLimitMs;
      controller.timerStarted = true;
      controller.timeLeft = s.timeLimitMs / 1000;
      controller.refreshHud();
    }
  }

  int completedTasks() {
    final s = state!;
    return s.items.where((e) => e.placed).length + s.careCompleted;
  }

  int totalTasks() {
    final s = state!;
    return s.items.length + s.room.care.length;
  }

  void activateCareOrFinish() {
    final s = state!;
    if (s.items.any((e) => !e.placed)) return;
    if (s.room.care.isNotEmpty) {
      s.careIndex = 0;
      s.activeCare = s.room.care[0];
      s.careProgress = 0;
      updateProgress();
      showToast(s.activeCare!.label, 2200);
      return;
    }
    beginCompletion();
  }

  void revealHiddenClutter() {
    final s = state!;
    final hidden = s.items.where((i) => i.hidden && !i.revealed && !i.placed);
    var reveals = hidden.where((i) {
      final cover = s.items.firstWhere(
        (c) => c.id == i.hiddenUnder,
        orElse: () => i,
      );
      return cover.placed;
    }).toList();
    final visibleRemaining = s.items.any((i) => !i.placed && i.revealed);
    if (reveals.isEmpty && !visibleRemaining && hidden.isNotEmpty) {
      reveals = [hidden.first];
    }
    if (reveals.isEmpty) return;
    for (final item in reveals) {
      item.revealed = true;
      item.revealUntil = _now + 900;
      burst(
        size.x * item.x,
        size.y * item.y,
        max(6, (sparkleCount * 0.65).round()),
      );
    }
    s.bunnyCheerUntilMs = _now + 900;
    showToast(
      reveals.length > 1
          ? '${reveals.length} hidden things found!'
          : 'Hidden clutter found!',
      1500,
    );
    HapticFeedback.lightImpact();
  }

  void finishCareAction() {
    final s = state!;
    final finished = s.activeCare;
    s.careCompleted += 1;
    s.careProgress = 0;
    s.careIndex += 1;
    s.activeCare = s.careIndex < s.room.care.length
        ? s.room.care[s.careIndex]
        : null;
    if (finished?.type == 'tap') s.plantBloom = true;
    playSfx('place');
    s.bunnyCheerUntilMs = _now + 850;
    burst(size.x * (finished?.x ?? 0.5), size.y * (finished?.y ?? 0.5));
    updateProgress();
    if (s.activeCare != null) {
      Timer(
        const Duration(milliseconds: 260),
        () => showToast(s.activeCare!.label, 2200),
      );
    } else {
      Timer(
        Duration(milliseconds: s.plantBloom ? 520 : 260),
        () => beginCompletion(),
      );
    }
  }

  int starsForRun() {
    final s = state!;
    if (!s.quick) return 1;
    final elapsed = s.elapsed;
    if (elapsed <= s.room.quick!.gold) return 3;
    if (elapsed <= s.room.quick!.silver) return 2;
    return 1;
  }

  void beginCompletion() {
    final s = state;
    if (s == null || s.completing) return;
    if (s.quick && s.timerStartMs != null) {
      s.elapsed = (_now - s.timerStartMs!) / 1000;
    }
    s.completing = true;
    s.completionStartedMs = _now;
    s.activeCare = null;
    s.progress = 1;
    s.bunnyCheerUntilMs = 1 << 62;
    controller.overlay = 'none';
    controller.targets = s.room.targets;
    final center = Offset(size.x / 2, size.y / 2);
    burst(center.dx, center.dy, sparkleCount * 2);

    final stars = starsForRun();
    final firstCompletion = !controller.save.completed[s.levelIndex];
    final reward = firstCompletion ? 100 + (stars - 1) * 25 : 25 * stars;
    controller.save.completed[s.levelIndex] = true;
    controller.save.stars[s.levelIndex] = max(
      controller.save.stars[s.levelIndex],
      stars,
    );
    controller.save.coins += reward;
    controller.save.unlocked = max(
      controller.save.unlocked,
      min(ROOMS.length, s.levelIndex + 2),
    );
    controller.save.selectedLevel = min(
      ROOMS.length - 1,
      s.levelIndex + (s.levelIndex + 1 < ROOMS.length ? 1 : 0),
    );
    playSfx('win');
    Timer(const Duration(milliseconds: 620), () => playSfx('coin'));
    int? quickScore;
    if (s.quick) {
      quickScore =
          s.levelIndex * 1000 + stars * 100 + max(0, 120 - s.elapsed.floor());
      controller.save.bestQuickScore = max(
        controller.save.bestQuickScore,
        quickScore,
      );
    }
    unawaited(controller.save.persist());
    updateProgress();
    final token = ++_completionToken;
    Timer(const Duration(milliseconds: 980), () {
      if (token != _completionToken) return;
      controller.overlay = 'completion';
      controller.overlayData = {
        'stars': stars,
        'reward': reward,
        'quickScore': quickScore,
        'finalRoom': s.levelIndex == ROOMS.length - 1,
        'shortName': s.room.shortName,
        'quick': s.quick,
        'elapsed': s.elapsed,
      };
      controller.refreshHud();
    });
  }

  void openPause() {
    final s = state;
    if (s == null || s.completing) return;
    s.paused = true;
    s.pauseBeganMs = _now;
    controller.overlay = 'pause';
    controller.overlayData = {'shortName': s.room.shortName};
    controller.refreshHud();
  }

  void resumeClock() {
    final s = state;
    if (s == null || !s.paused) return;
    if (s.timerStartMs != null && s.pauseBeganMs != null) {
      s.timerStartMs = s.timerStartMs! + (_now - s.pauseBeganMs!);
    }
    s.paused = false;
    s.pauseBeganMs = null;
    controller.overlay = 'none';
    controller.refreshHud();
  }

  void onTimeUp() {
    final s = state;
    if (s == null || controller.overlay == 'gameover') return;
    s.timeUp = true;
    s.timeLeftMs = 0;
    controller.timeLeft = 0;
    s.paused = true;
    controller.overlay = 'gameover';
    controller.refreshHud();
  }

  void openAlbum(String tab) {
    final s = state;
    if (s != null && !s.completing && controller.overlay != 'menu') {
      s.paused = true;
      s.pauseBeganMs = _now;
    }
    if (controller.overlay != 'album-rooms' &&
        controller.overlay != 'album-wardrobe') {
      _albumReturn = controller.overlay;
    }
    controller.overlay = tab == 'wardrobe' ? 'album-wardrobe' : 'album-rooms';
    if (pack != null) {
      if (tab == 'wardrobe') {
        unawaited(
          pack!
              .ensure(SKINS.map((s) => s.sheet).toSet().toList())
              .then((_) => controller.refreshHud()),
        );
      } else {
        unawaited(
          pack!
              .ensure(ROOMS.map((r) => r.assetKey).toList())
              .then((_) => controller.refreshHud()),
        );
      }
    }
    controller.refreshHud();
  }

  void closeAlbum() {
    controller.overlay =
        _albumReturn == 'album-rooms' || _albumReturn == 'album-wardrobe'
        ? 'menu'
        : _albumReturn;
    if (controller.overlay == 'none' && state != null) {
      state!.paused = false;
    }
    controller.refreshHud();
  }

  void openMenu() {
    if (state != null) {
      state!.paused = true;
      state!.pauseBeganMs = _now;
    }
    controller.overlay = 'menu';
    controller.refreshHud();
  }

  void openTutorial() {
    final s = state;
    if (controller.overlay == 'menu') {
      _tutorialReturn = 'menu';
    } else {
      // Opened from inside a room: pause the clock and return to play after.
      _tutorialReturn = 'none';
      if (s != null && !s.completing) {
        s.paused = true;
        s.pauseBeganMs = _now;
      }
    }
    controller.overlay = 'tutorial';
    controller.refreshHud();
  }

  Future<void> closeTutorial() async {
    controller.save.tutorialSeen = true;
    await controller.save.persist();
    final s = state;
    if (_tutorialReturn == 'none' && s != null) {
      if (s.timerStartMs != null && s.pauseBeganMs != null) {
        s.timerStartMs = s.timerStartMs! + (_now - s.pauseBeganMs!);
      }
      s.pauseBeganMs = null;
      s.paused = false;
      controller.overlay = 'none';
    } else {
      controller.overlay = 'menu';
    }
    controller.refreshHud();
  }

  void toggleMute() {
    final nextMuted = !controller.save.muted;
    controller.save.muted = nextMuted;
    unawaited(controller.save.persist());
    _audio?.setMuted(nextMuted);
    if (!nextMuted) {
      _audio?.unlock();
      playSfx('click');
    }
    controller.refreshHud();
  }

  Future<void> resetProgress() async {
    controller.save.reset();
    await controller.save.persist();
    controller.loading = false;
    controller.overlay = 'menu';
    controller.refreshHud();
  }

  void selectSkin(String skinId) {
    final save = controller.save;
    final owned = save.ownedSkins.contains(skinId);
    if (!owned) {
      final skin = SKINS.firstWhere((s) => s.id == skinId);
      if (skin.cost <= 0 || save.coins < skin.cost) return;
      save.coins -= skin.cost;
      save.ownedSkins.add(skinId);
    }
    save.skin = skinId;
    if (state != null) state!.skin = skinId;
    playSfx('coin');
    unawaited(save.persist());
    controller.coins = save.coins;
    updateProgress();
    openAlbum('wardrobe');
  }

  void showToastHit(String message) => showToast(message, 1200);

  bool pointerDown(Offset local) {
    _audio?.unlock();
    final s = state;
    if (s == null || s.paused || s.completing) return false;
    final careHit = s.activeCare != null && careContains(local);
    final itemId = s.activeCare != null ? null : itemAt(local);
    if (!careHit && itemId == null) return false;
    startTimerOnAction();
    if (careHit) {
      if (s.activeCare!.type == 'tap') {
        onCareTap(local);
        return true;
      }
      _mode = 'care';
      _lastPoint = local;
      return true;
    }
    _mode = 'drag';
    onPick(itemId!, local);
    return true;
  }

  void pointerMove(Offset local) {
    final s = state;
    if (s == null || _mode == null) return;
    if (_mode == 'drag') {
      onMove(local);
    } else if (_mode == 'care' && careContains(local)) {
      final distance = (_lastPoint - local).distance;
      onCareSwipe(distance, local);
    }
    _lastPoint = local;
  }

  void pointerUp(Offset global) {
    final s = state;
    if (s == null) return;
    if (_mode == 'drag') onDrop(global);
    _mode = null;
  }

  void onPick(String itemId, Offset point) {
    final s = state!;
    s.draggedId = itemId;
    final entry = s.items.firstWhere((e) => e.id == itemId);
    entry.dragX = point.dx;
    entry.dragY = point.dy;
    playSfx('jump');
  }

  void onMove(Offset point) {
    final s = state!;
    final entry = s.items.firstWhere((e) => e.id == s.draggedId);
    entry.dragX = point.dx;
    entry.dragY = point.dy;
  }

  void onDrop(Offset global) {
    final s = state!;
    final entry = s.items.firstWhere((e) => e.id == s.draggedId);
    s.draggedId = null;
    final target = targetAt(global);
    final correct = target == entry.target;
    if (!correct) {
      entry.bounceUntil = _now + 360;
      s.bunnyUpsetUntilMs = _now + 1000;
      showToast('Not there — try another basket', 1200);
      HapticFeedback.selectionClick();
      playSfx('hit');
      return;
    }
    entry.placed = true;
    s.bunnyCheerUntilMs = _now + 760;
    playSfx('place');
    burst(
      entry.dragX.clamp(12, size.x - 12),
      entry.dragY.clamp(12, size.y - 12),
    );
    HapticFeedback.lightImpact();
    revealHiddenClutter();
    updateProgress();
    activateCareOrFinish();
  }

  void onCareSwipe(double distance, Offset point) {
    final s = state!;
    if (s.activeCare == null || s.activeCare!.type != 'swipe') return;
    s.careProgress = (s.careProgress + distance / wipeDistance).clamp(0, 1);
    if (_now - _lastSwipeSoundMs > 150) {
      _lastSwipeSoundMs = _now;
      burst(point.dx, point.dy, 2);
      playSfx('swipe');
    }
    if (s.careProgress >= 1) finishCareAction();
  }

  void onCareTap(Offset point) {
    final s = state!;
    if (s.activeCare == null || s.activeCare!.type != 'tap') return;
    burst(point.dx, point.dy, sparkleCount);
    finishCareAction();
  }

  String? itemAt(Offset point) {
    final entries = _itemRects.entries.toList().reversed;
    for (final e in entries) {
      final r = e.value;
      if (point.dx >= r.left &&
          point.dx <= r.right &&
          point.dy >= r.top &&
          point.dy <= r.bottom) {
        return e.key;
      }
    }
    return null;
  }

  bool careContains(Offset point) {
    final r = _careRect;
    return r != null &&
        point.dx >= r.left &&
        point.dx <= r.right &&
        point.dy >= r.top &&
        point.dy <= r.bottom;
  }

  String? targetAt(Offset global) {
    for (final hit in controller.targetRects) {
      if (hit.rect.contains(global)) return hit.id;
    }
    return null;
  }

  void burst(double x, double y, [int amount = 16]) {
    const colors = [
      Color(0xFFFFE776),
      Color(0xFFFFAEAE),
      Color(0xFFB4DCb2),
      Color(0xFFDCBEEe),
    ];
    for (int i = 0; i < amount; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = 0.035 + _random.nextDouble() * 0.09;
      final life = 520 + _random.nextDouble() * 440;
      _particles.add(
        Particle(
          x,
          y,
          cos(angle) * speed,
          sin(angle) * speed - 0.035,
          life,
          life,
          3 + _random.nextDouble() * 5,
          (_random.nextDouble() - 0.5) * 0.02,
          colors[i % colors.length],
        ),
      );
    }
  }

  @override
  void update(double dt) {
    _now = DateTime.now().millisecondsSinceEpoch;
    final s = state;
    if (s != null && !s.paused && !s.completing) {
      if (s.quick && s.timerStartMs != null) {
        s.elapsed = (_now - s.timerStartMs!) / 1000;
        final sec = s.elapsed.floor();
        if (sec != _lastShownSec) {
          _lastShownSec = sec;
          controller.elapsed = s.elapsed;
          controller.refreshHud();
        }
      } else if (!s.quick && s.timerStartMs != null && !s.timeUp) {
        final remaining = s.timeLimitMs - (_now - s.timerStartMs!);
        s.timeLeftMs = remaining > 0 ? remaining : 0;
        if (s.timeLeftMs <= 0) {
          s.timeUp = true;
          s.paused = true;
          onTimeUp();
        } else {
          final sec = (s.timeLeftMs / 1000).ceil();
          if (sec != _lastShownSec) {
            _lastShownSec = sec;
            controller.timeLeft = s.timeLeftMs / 1000;
            controller.refreshHud();
          }
        }
      }
    }
    if (controller.overlay != 'none') return;
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt * 1000;
      if (p.life <= 0) {
        _particles.removeAt(i);
        continue;
      }
      p.x += p.vx * dt * 1000;
      p.y += p.vy * dt * 1000;
      p.vy += 0.00016 * dt * 1000;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (pack == null || state == null) return;
    if (controller.overlay != 'none') return;
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;
    final s = state!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF3a2740),
    );
    final bg = pack!.images[s.room.assetKey];
    if (bg != null) _drawCover(canvas, bg, w, h);
    final dim = 0.12 * (1 - s.progress);
    if (dim > 0.005) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF4C3148).withValues(alpha: dim),
      );
    }
    _drawItems(canvas, w, h);
    _drawBunny(canvas, w, h);
    _drawCare(canvas, w, h);
    _drawParticles(canvas, dt: 0);
    _drawCompletionGlow(canvas, w, h);
  }

  void _drawCover(ui.Canvas canvas, ui.Image image, double w, double h) {
    final ir = image.width / image.height;
    final tr = w / h;
    double sx = 0,
        sy = 0,
        sw = image.width.toDouble(),
        sh = image.height.toDouble();
    if (ir > tr) {
      sw = image.height * tr;
      sx = (image.width - sw) / 2;
    } else {
      sh = image.width / tr;
      sy = max(0, (image.height - sh) * 0.42);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(sx, sy, sw, sh),
      Rect.fromLTWH(0, 0, w, h),
      Paint(),
    );
  }

  void _drawFrameInCell(
    ui.Canvas canvas,
    ui.Image? image,
    Frame? frame,
    double x,
    double y,
    double w,
    double h, [
    double opacity = 1,
  ]) {
    if (image == null || frame == null) return;
    final crop = frame.content;
    final scale = min(w / crop.width, h / crop.height);
    final dw = crop.width * scale;
    final dh = crop.height * scale;
    canvas.drawImageRect(
      image,
      crop,
      Rect.fromLTWH(x + (w - dw) / 2, y + (h - dh) / 2, dw, dh),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: opacity),
    );
  }

  void _drawAnimationAnchored(
    ui.Canvas canvas,
    ui.Image? image,
    SpriteAnimation? animation,
    int frameIndex,
    double anchorX,
    double anchorY,
    double maxW,
    double maxH, [
    double rotation = 0,
  ]) {
    if (image == null || animation == null || animation.frames.isEmpty) return;
    final frame = animation.frames[frameIndex % animation.frames.length];
    double largestW = 1, largestH = 1;
    for (final f in animation.frames) {
      largestW = max(largestW, f.content.width);
      largestH = max(largestH, f.content.height);
    }
    final scale = min(maxW / largestW, maxH / largestH);
    final crop = frame.content;
    final pin = frame.anchor;
    final dx = anchorX - (pin.dx - crop.left) * scale;
    final dy = anchorY - (pin.dy - crop.top) * scale;
    if (rotation != 0) {
      canvas.save();
      canvas.translate(anchorX, anchorY);
      canvas.rotate(rotation);
      canvas.translate(-anchorX, -anchorY);
    }
    canvas.drawImageRect(
      image,
      crop,
      Rect.fromLTWH(dx, dy, crop.width * scale, crop.height * scale),
      Paint(),
    );
    if (rotation != 0) canvas.restore();
  }

  void _drawBunny(ui.Canvas canvas, double w, double h) {
    final s = state!;
    final cheer = s.bunnyCheerUntilMs > _now || s.completing;
    final upset = s.bunnyUpsetUntilMs > _now;
    final animName = '${s.skin}_${cheer ? 'cheer' : 'idle'}';
    final sheetKey = skinSheet(s.skin);
    SpriteAnimation? anim;
    ui.Image? image;
    if (pack!.sheets[sheetKey] != null) {
      anim = animationNamed(pack!.sheets[sheetKey], animName);
      if (anim != null) image = pack!.images[sheetKey];
    }
    if (anim == null && pack!.sheets['BUNNY_SHEET'] != null) {
      anim = animationNamed(pack!.sheets['BUNNY_SHEET'], 'classic_idle');
      image = pack!.images['BUNNY_SHEET'];
    }
    final frameIndex = (_now ~/ (cheer ? 155 : 330)) % 3;
    final bunnyH = h * 0.36;
    final bunnyW = bunnyH * 0.96;
    final anchorX = w * 0.78;
    final anchorY = h * 0.94;
    final rotation = upset ? sin(_now / 55) * 0.12 : 0.0;
    _drawAnimationAnchored(
      canvas,
      image,
      anim,
      frameIndex,
      anchorX,
      anchorY,
      bunnyW,
      bunnyH,
      rotation,
    );
    if (upset) {
      // Sit the anger mark on the bunny's head/temple so it reads as part
      // of the character instead of floating beside it.
      final headX = anchorX + bunnyW * 0.20;
      final headY = anchorY - bunnyH * 0.74;
      _drawUpsetMark(canvas, headX, headY, bunnyH);
    }
  }

  void _drawUpsetMark(ui.Canvas canvas, double x, double y, double bunnyH) {
    // Classic manga "popping vein" (💢) anger mark, scaled to the character
    // so it grows with the bunny and overlaps the head.
    final r = bunnyH * 0.14;
    final pulse = 1 + sin(_now / 90) * 0.08;
    final color = const Color(0xFFFF3B3B);

    // Soft halo so the mark blends into the character silhouette.
    canvas.drawCircle(
      Offset(x, y),
      r * 1.15 * pulse,
      Paint()..color = color.withValues(alpha: 0.18),
    );

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = bunnyH * 0.032
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final vein = Path();
    final tipR = r * pulse;
    final wingR = tipR * 0.62;
    const wingSpread = 2.25;
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      final tipX = x + cos(a) * tipR;
      final tipY = y + sin(a) * tipR;
      vein.moveTo(x + cos(a + wingSpread) * wingR, y + sin(a + wingSpread) * wingR);
      vein.lineTo(tipX, tipY);
      vein.lineTo(x + cos(a - wingSpread) * wingR, y + sin(a - wingSpread) * wingR);
    }
    canvas.drawPath(vein, stroke);
    canvas.drawCircle(Offset(x, y), bunnyH * 0.022, Paint()..color = color);
  }

  void _drawCare(ui.Canvas canvas, double w, double h) {
    final s = state!;
    _careRect = null;
    final action = s.activeCare;
    if (action == null && !s.plantBloom) return;
    final subject = s.plantBloom
        ? CareDef(
            type: 'tap',
            sprite: 'blooming_plant',
            atlas: 'CARE_ATLAS',
            label: '',
            x: 0.52,
            y: 0.48,
            w: 0.28,
            h: 0.34,
          )
        : action!;
    final rect = Rect.fromLTWH(
      w * (subject.x - subject.w / 2),
      h * (subject.y - subject.h / 2),
      w * subject.w,
      h * subject.h,
    );
    _careRect = rect;
    canvas.save();
    final careSheet = subject.atlas;
    final img = pack!.images[careSheet];
    final sheet = pack!.sheets[careSheet];
    _drawFrameInCell(
      canvas,
      img,
      frameNamed(sheet, subject.sprite),
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    );
    if (action?.type == 'tap' && !s.plantBloom) {
      final pulse = 0.5 + sin(_now / 240) * 0.18;
      final gradient = RadialGradient(
        colors: [Color(0xFFFFEC98).withValues(alpha: pulse), const Color(0x00FFEC98)],
        stops: const [0, 1],
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = gradient.createShader(rect)
          ..blendMode = BlendMode.screen,
      );
    }
    canvas.restore();
  }

  void _drawItems(ui.Canvas canvas, double w, double h) {
    final s = state!;
    _itemRects.clear();
    final baseSize = (min(w, h) * 0.175 * itemScale).clamp(50, 94);
    for (final item in s.items) {
      if (item.placed || !item.revealed) continue;
      final dragging = s.draggedId == item.id;
      final revealing = item.revealUntil > _now;
      final size =
          baseSize *
          item.scale *
          (dragging
              ? 1.16
              : revealing
              ? 1.1
              : 1);
      final cx = dragging ? item.dragX : w * item.x;
      final cy = dragging ? item.dragY : h * item.y;
      double px = cx;
      double py = cy;
      if (!dragging && item.bounceUntil > _now) {
        final remaining = item.bounceUntil - _now;
        px += sin(remaining / 28) * 7 * (remaining / 360);
      }
      final rect = Rect.fromLTWH(px - size / 2, py - size / 2, size, size);
      _itemRects[item.id] = rect;
      if (dragging || revealing) {
        final halo = RadialGradient(
          colors: [
            (revealing ? const Color(0xFFFFE784) : const Color(0xFFFFF4B2))
                .withValues(alpha: revealing ? 0.88 : 0.72),
            const Color(0x00FFF4B2),
          ],
          stops: const [0, 1],
        );
        canvas.drawRect(
          Rect.fromLTWH(
            px - size * 0.75,
            py - size * 0.75,
            size * 1.5,
            size * 1.5,
          ),
          Paint()
            ..shader = halo.createShader(
              Rect.fromLTWH(
                px - size * 0.75,
                py - size * 0.75,
                size * 1.5,
                size * 1.5,
              ),
            )
            ..blendMode = BlendMode.screen,
        );
      }
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(dragging ? item.rotation * 0.35 : item.rotation);
      final objSheet = item.atlas;
      final blend = (dragging || revealing) ? 1.0 : itemOpacity;
      _drawFrameInCell(
        canvas,
        pack!.images[objSheet],
        frameNamed(pack!.sheets[objSheet], item.sprite),
        -size / 2,
        -size / 2,
        size,
        size,
        blend,
      );
      canvas.restore();
    }
  }

  void _drawParticles(ui.Canvas canvas, {double dt = 0}) {
    final path = Path();
    final paint = Paint();
    for (final p in _particles) {
      final alpha = (p.life / p.maxLife).clamp(0, 1);
      final r = p.size * (0.65 + alpha * 0.35);
      final c = Offset(p.x, p.y);
      path.reset();
      path.moveTo(c.dx, c.dy - r);
      path.lineTo(c.dx + r * 0.28, c.dy - r * 0.28);
      path.lineTo(c.dx + r, c.dy);
      path.lineTo(c.dx + r * 0.28, c.dy + r * 0.28);
      path.lineTo(c.dx, c.dy + r);
      path.lineTo(c.dx - r * 0.28, c.dy + r * 0.28);
      path.lineTo(c.dx - r, c.dy);
      path.lineTo(c.dx - r * 0.28, c.dy - r * 0.28);
      path.close();
      paint.color = p.color.withValues(alpha: alpha.toDouble());
      canvas.drawPath(path, paint);
    }
  }

  void _drawCompletionGlow(ui.Canvas canvas, double w, double h) {
    final s = state!;
    if (!s.completing) return;
    final age = max(0, _now - s.completionStartedMs);
    final alpha = (age / 750).clamp(0, 1) * 0.26;
    final gradient = RadialGradient(
      colors: [
        Color(0xFFFFFAD1).withValues(alpha: alpha + 0.2),
        const Color(0x00FFF0C4),
      ],
      stops: const [0, 1],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h))
        ..blendMode = BlendMode.screen,
    );
  }
}
