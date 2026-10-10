import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';

import 'cleaner_game.dart';
import 'data.dart';
import 'frames.dart';
import 'save.dart';

String formatTime(double? seconds) {
  final safe = (seconds ?? 0).clamp(0, 99999);
  final m = safe.floor() ~/ 60;
  final r = (safe.floor() % 60).toString().padLeft(2, '0');
  return '$m:$r';
}

class FrameIcon extends StatelessWidget {
  final ui.Image? image;
  final Frame? frame;
  final double size;

  const FrameIcon(this.image, this.frame, this.size, {super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: _FramePainter(image, frame),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final ui.Image? image;
  final Frame? frame;

  _FramePainter(this.image, this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null || frame == null) return;
    final crop = frame!.content;
    final scale = (size.width / crop.width).clamp(0, size.height / crop.height);
    final dw = crop.width * scale;
    final dh = crop.height * scale;
    canvas.drawImageRect(
      image!,
      crop,
      Rect.fromLTWH((size.width - dw) / 2, (size.height - dh) / 2, dw, dh),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.image != image || old.frame != frame;
}

class CoverImage extends StatelessWidget {
  final ui.Image? image;
  final double width;
  final double height;

  const CoverImage(this.image, this.width, this.height, {super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _CoverPainter(image),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  final ui.Image? image;

  _CoverPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF5a3a62),
      );
      return;
    }
    final ir = image!.width / image!.height;
    final tr = size.width / size.height;
    double sx = 0,
        sy = 0,
        sw = image!.width.toDouble(),
        sh = image!.height.toDouble();
    if (ir > tr) {
      sw = image!.height * tr;
      sx = (image!.width - sw) / 2;
    } else {
      sh = image!.width / tr;
      sy = (image!.height - sh) * 0.42;
    }
    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(sx, sy, sw, sh),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) => old.image != image;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  late final CleanerGame _game;

  @override
  void initState() {
    super.initState();
    _controller = GameController(SaveData.defaults());
    _game = CleanerGame(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3a2740),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Hud(game: _game, controller: _controller),
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanDown: (d) => _game.pointerDown(d.localPosition),
                      onPanUpdate: (d) => _game.pointerMove(d.localPosition),
                      onPanEnd: (d) => _game.pointerUp(d.globalPosition),
                      child: GameWidget(game: _game),
                    ),
                  ),
                ),
                TargetBar(game: _game, controller: _controller),
              ],
            ),
            OverlayLayer(game: _game, controller: _controller),
          ],
        ),
      ),
    );
  }
}

class Hud extends StatelessWidget {
  final CleanerGame game;
  final GameController controller;
  const Hud({required this.game, required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: const Color(0xFF4a2f50),
        child: Row(
          children: [
            IconButton(
              onPressed: () => game.openAlbum('rooms'),
              icon: const Icon(Icons.home, color: Colors.white),
              iconSize: 22,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          controller.roomName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${controller.completed}/${controller.total}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: controller.progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFE08a)),
                  ),
                ],
              ),
            ),
            if (controller.quick || controller.timerStarted)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      formatTime(
                        controller.quick
                            ? controller.elapsed
                            : controller.timeLeft,
                      ),
                      style: TextStyle(
                        color: !controller.quick && controller.timeLeft <= 10
                            ? Colors.red
                            : Colors.white,
                        fontWeight:
                            !controller.quick && controller.timeLeft <= 10
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Color(0xFFFFD36b), size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${controller.coins}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => game.openTutorial(),
              icon: const Icon(Icons.help_outline, color: Colors.white),
              iconSize: 22,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: 'How to play',
            ),
            IconButton(
              onPressed: () => game.toggleMute(),
              icon: Icon(
                controller.save.muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              iconSize: 22,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: controller.save.muted ? 'Unmute' : 'Mute',
            ),
            IconButton(
              onPressed: () => game.openPause(),
              icon: const Icon(Icons.pause, color: Colors.white),
              iconSize: 22,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          ],
        ),
      ),
    );
  }
}

class TargetBar extends StatefulWidget {
  final CleanerGame game;
  final GameController controller;
  const TargetBar({required this.game, required this.controller, super.key});

  @override
  State<TargetBar> createState() => _TargetBarState();
}

class _TargetBarState extends State<TargetBar> {
  final Map<int, GlobalKey> _keys = {};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final targets = widget.controller.targets ?? [];
        if (targets.isEmpty) return const SizedBox(height: 92);
        if (widget.controller.overlay != 'none') {
          return const SizedBox(height: 92);
        }
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _recordRects(targets),
        );
        return Container(
          height: 92,
          color: const Color(0xFF4a2f50),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: targets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = targets[i];
              final key = GlobalKey();
              _keys[i] = key;
              final sheet = widget.game.pack?.sheets[t.atlas];
              final img = widget.game.pack?.images[t.atlas];
              return Container(
                key: key,
                width: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: FrameIcon(img, frameNamed(sheet, t.id), 46),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _recordRects(List<TargetDef> targets) {
    final hits = <TargetHit>[];
    for (int i = 0; i < targets.length; i++) {
      final key = _keys[i];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      hits.add(TargetHit(targets[i].id, topLeft & box.size));
    }
    widget.controller.targetRects = hits;
  }
}

class OverlayLayer extends StatelessWidget {
  final CleanerGame game;
  final GameController controller;
  const OverlayLayer({required this.game, required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return Stack(
            children: [
              _scrim(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cleaning_services,
                      size: 54,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.loadingMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (controller.toast != null) _toastPopup(),
            ],
          );
        }
        final overlay = switch (controller.overlay) {
          'menu' => _menu(context),
          'completion' => _completionCard(),
          'pause' => _pauseCard(),
          'timeup' => _timeUpCard(),
          'gameover' => _timeUpCard(),
          'album-rooms' => _albumRooms(),
          'album-wardrobe' => _albumWardrobe(),
          'tutorial' => _tutorialCard(),
          _ => const SizedBox.shrink(),
        };
        return Stack(
          children: [overlay, if (controller.toast != null) _toastPopup()],
        );
      },
    );
  }

  Widget _toastPopup() => Positioned(
    left: 20,
    right: 20,
    bottom: 108,
    child: IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFE85D5D),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  controller.toast!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _scrim({required Widget child}) => Container(
    color: Colors.black54,
    child: Center(child: child),
  );

  Widget _card({required Widget child}) => _scrim(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF5a3a62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    ),
  );

  Widget _starPips(int count, {double size = 34}) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [0, 1, 2]
        .map(
          (i) => Text(
            i < count ? '★' : '☆',
            style: TextStyle(
              fontSize: size,
              color: i < count ? const Color(0xFFFFD36b) : Colors.white38,
            ),
          ),
        )
        .toList(),
  );

  Widget _completionCard() {
    final d = controller.overlayData;
    final stars = d['stars'] as int;
    final reward = d['reward'] as int;
    final quick = d['quick'] as bool;
    final quickScore = d['quickScore'] as int?;
    final finalRoom = d['finalRoom'] as bool;
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ROOM CLEAN',
            style: TextStyle(color: Colors.white70, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Text(
            d['shortName'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _starPips(stars),
          if (quick)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${formatTime(d['elapsed'] as double)} · Clean score $quickScore',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '● +$reward',
              style: const TextStyle(color: Color(0xFFFFD36b), fontSize: 20),
            ),
          ),
          const SizedBox(height: 8),
          if (!finalRoom)
            _btn(
              'Next room',
              true,
              () => game.startRoom(game.state!.levelIndex + 1, false),
            ),
          _btn(
            'Quick Clean',
            false,
            () => game.startRoom(game.state!.levelIndex, true),
          ),
          _btn('Room album', false, () => game.openAlbum('rooms')),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final save = controller.save;
    final sheet = game.pack?.sheets['BUNNY_SHEET'];
    final img = game.pack?.images['BUNNY_SHEET'];
    final frame = frameNamed(sheet, 'classic_idle_1');
    final hasProgress =
        save.unlocked > 1 || save.coins > 0 || save.stars.any((s) => s > 0);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6a3f8a), Color(0xFF3a2740), Color(0xFF2b5d6b)],
        ),
      ),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: FrameIcon(img, frame, 130),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hop\'N Mop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Text(
                'Tidy every room with the bunny!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              _btn(
                hasProgress ? 'Continue' : 'Play',
                true,
                () => game.startRoom(save.selectedLevel, false),
              ),
              _btn('How to play', false, () => game.openTutorial()),
              _btn('Room Album', false, () => game.openAlbum('rooms')),
              _btn('Bunny Wardrobe', false, () => game.openAlbum('wardrobe')),
              _btn('Reset progress', false, () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF5a3a62),
                    title: const Text(
                      'Reset progress?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Stars, coins and unlocked rooms will be cleared.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await game.resetProgress();
              }),
              _btn('Log out', false, () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF5a3a62),
                    title: const Text(
                      'Log out dari game?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Progress kamu tetap tersimpan.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await SystemNavigator.pop();
              }),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.circle,
                      color: Color(0xFFFFD36b),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${save.coins}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tutorialCard() => TutorialCard(game: game, controller: controller);

  Widget _pauseCard() {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(color: Colors.white70, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Text(
            controller.overlayData['shortName'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _btn('Keep cleaning', true, () => game.resumeClock()),
          _btn('Room album', false, () => game.openAlbum('rooms')),
          _btn('Bunny wardrobe', false, () => game.openAlbum('wardrobe')),
          _btn('Main menu', false, () => game.openMenu()),
        ],
      ),
    );
  }

  Widget _timeUpCard() {
    final shortName = game.state?.room.shortName ?? '';
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_off_rounded,
            color: Colors.redAccent,
            size: 46,
          ),
          const SizedBox(height: 8),
          const Text(
            'GAME OVER',
            style: TextStyle(
              color: Colors.red,
              letterSpacing: 2,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            shortName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Time's up! The room is still messy.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _btn(
            'Retry',
            true,
            () => game.startRoom(game.state!.levelIndex, false),
          ),
          _btn('Main menu', false, () => game.openMenu()),
        ],
      ),
    );
  }

  Widget _albumRooms() {
    final save = controller.save;
    final sections = <({String world, List<int> rooms})>[];
    String? cur;
    for (int i = 0; i < ROOMS.length; i++) {
      final r = ROOMS[i];
      if (r.world != cur) {
        cur = r.world;
        sections.add((world: r.world, rooms: <int>[]));
      }
      sections.last.rooms.add(i);
    }
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room Album',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${save.stars.reduce((a, b) => a + b)} / ${ROOMS.length * 3} ★',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          color: Color(0xFFFFD36b),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${save.coins}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      game.playSfx('click');
                      game.closeAlbum();
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RepaintBoundary(
              child: ListView(
                children: sections.map((s) => _roomSection(s)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomSection(({String world, List<int> rooms}) section) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD36b),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          section.world,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.86,
        children: section.rooms.map(_roomCard).toList(),
      ),
    ],
  );

  Widget _roomCard(int i) {
    final room = ROOMS[i];
    final save = controller.save;
    final locked = i >= save.unlocked;
    final complete = save.completed[i];
    final img = game.pack?.images[room.assetKey];
    return InkWell(
      onTap: locked
          ? null
          : () {
              game.playSfx('click');
              game.startRoom(i, save.completed[i]);
            },
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: locked ? Colors.transparent : Colors.white24,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(img, 200, 232),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                ),
              ),
            ),
            if (locked)
              const Center(
                child: Icon(Icons.lock, color: Colors.white70, size: 30),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Column(
                children: [
                  Text(
                    room.shortName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _starPips(save.stars[i], size: 12),
                ],
              ),
            ),
            if (complete)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xFFFFD36b),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _albumWardrobe() {
    final save = controller.save;
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '● ${save.coins}',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  game.playSfx('click');
                  game.closeAlbum();
                },
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: RepaintBoundary(
              child: GridView.count(
                crossAxisCount: 3,
                children: SKINS.map((skin) {
                  final owned = save.ownedSkins.contains(skin.id);
                  final selected = save.skin == skin.id;
                  final canPurchase = owned || save.coins >= skin.cost;
                  final locked = !owned;
                  final sheetKey = skin.sheet;
                  final img = game.pack?.images[sheetKey];
                  final sheet = game.pack?.sheets[sheetKey];
                  final frame = frameNamed(sheet, '${skin.id}_idle_1');
                  return InkWell(
                    onTap: !canPurchase
                        ? null
                        : () {
                            game.playSfx('click');
                            game.selectSkin(skin.id);
                          },
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFD36b)
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: locked
                            ? Colors.black26
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: locked ? 0.35 : 1,
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: FrameIcon(img, frame, 56),
                                ),
                              ),
                              if (locked)
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                            ],
                          ),
                          Text(
                            skin.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            selected
                                ? 'Wearing'
                                : owned
                                ? 'Choose'
                                : '● ${skin.cost}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, bool primary, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary
              ? const Color(0xFFFFD36b)
              : const Color(0xFF6a4572),
          foregroundColor: primary ? Colors.black : Colors.white,
        ),
        onPressed: () {
          game.playSfx('click');
          onTap();
        },
        child: Text(label),
      ),
    ),
  );
}

class TutorialCard extends StatefulWidget {
  final CleanerGame game;
  final GameController controller;
  const TutorialCard({
    required this.game,
    required this.controller,
    super.key,
  });

  @override
  State<TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends State<TutorialCard> {
  static const _pages = [
    (
      icon: Icons.emoji_people_rounded,
      title: 'Help the bunny clean',
      body: 'Every room is a mess! Your job is to tidy each one with the '
          'cleaning bunny. Tap Play to jump into the first room.',
    ),
    (
      icon: Icons.open_with_rounded,
      title: 'Sort the clutter',
      body: 'Drag each object onto its matching basket. The bottom bar shows '
          'what goes where — a shirt goes to Clothes, a book to Books. '
          'Drop it in the wrong spot and it bounces back!',
    ),
    (
      icon: Icons.water_drop_rounded,
      title: 'Care tasks',
      body: 'After sorting, a care task pops up. Swipe across a stain to '
          'wipe or scrub it, or tap a glowing spot to water a plant. '
          'Finish every task to finish the room.',
    ),
    (
      icon: Icons.visibility_rounded,
      title: 'Hidden clutter',
      body: 'Some items hide under others. Place the covering object and the '
          'hidden clutter appears with a sparkle — don’t leave it behind!',
    ),
    (
      icon: Icons.timer_rounded,
      title: 'Beat the clock',
      body: 'The timer starts on your first move. In Quick Clean, finish '
          'before the limit for gold or silver stars. Run out of time and '
          'it’s game over — just retry!',
    ),
    (
      icon: Icons.stars_rounded,
      title: 'Earn & dress up',
      body: 'Clean rooms to earn coins and stars. Spend coins in the Bunny '
          'Wardrobe on cute outfits, then keep tidying to unlock new worlds.',
    ),
  ];

  int _page = 0;

  void _next() {
    widget.game.playSfx('click');
    if (_page < _pages.length - 1) {
      setState(() => _page++);
    } else {
      unawaited(widget.game.closeTutorial());
    }
  }

  void _skip() {
    widget.game.playSfx('click');
    unawaited(widget.game.closeTutorial());
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final last = _page == _pages.length - 1;
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF5a3a62),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HOW TO PLAY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Icon(
                page.icon,
                size: 56,
                color: const Color(0xFFFFD36b),
              ),
              const SizedBox(height: 14),
              Text(
                page.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                page.body,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? const Color(0xFFFFD36b)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD36b),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _next,
                      child: Text(last ? 'Start cleaning!' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
