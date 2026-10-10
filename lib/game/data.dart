import 'dart:math';

const GRID = [
  [0.11, 0.58],
  [0.31, 0.58],
  [0.51, 0.58],
  [0.7, 0.58],
  [0.11, 0.67],
  [0.31, 0.67],
  [0.51, 0.67],
  [0.7, 0.67],
  [0.11, 0.76],
  [0.31, 0.76],
  [0.51, 0.76],
  [0.7, 0.76],
  [0.11, 0.84],
  [0.31, 0.84],
  [0.51, 0.84],
  [0.7, 0.84],
];

class TargetDef {
  final String id;
  final String label;
  final String atlas;

  TargetDef(this.id, this.label, [this.atlas = 'TARGET_ATLAS']);
}

class CareDef {
  final String type;
  final String sprite;
  final String atlas;
  final String label;
  final double x;
  final double y;
  final double w;
  final double h;

  CareDef({
    required this.type,
    required this.sprite,
    required this.atlas,
    required this.label,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class RoomItem {
  final String id;
  final String sprite;
  final String target;
  final String atlas;
  double x;
  double y;
  double rotation;
  final double scale;

  bool hidden;
  String? hiddenUnder;

  bool placed = false;
  bool revealed;
  double bounceUntil = 0;
  double revealUntil = 0;
  double dragX = 0;
  double dragY = 0;

  RoomItem({
    required this.id,
    required this.sprite,
    required this.target,
    required this.atlas,
    required this.x,
    required this.y,
    required this.rotation,
    required this.scale,
    this.hidden = false,
    this.hiddenUnder,
    this.revealed = true,
  });
}

class QuickDef {
  final int gold;
  final int silver;

  QuickDef(this.gold, this.silver);
}

class Room {
  final String id;
  final String world;
  final String name;
  final String shortName;
  final String assetKey;
  final List<TargetDef> targets;
  final List<RoomItem> items;
  final List<CareDef> care;
  final QuickDef? quick;

  Room({
    required this.id,
    required this.world,
    required this.name,
    required this.shortName,
    required this.assetKey,
    required this.targets,
    required this.items,
    required this.care,
    this.quick,
  });
}

class Skin {
  final String id;
  final String name;
  final int cost;
  final String sheet;

  Skin(this.id, this.name, this.cost, this.sheet);
}

TargetDef target(String id, String label, [String atlas = 'TARGET_ATLAS']) =>
    TargetDef(id, label, atlas);

CareDef swipe(
  String sprite,
  String atlas,
  String label, [
  double x = 0.5,
  double y = 0.58,
  double w = 0.34,
  double h = 0.2,
]) => CareDef(
  type: 'swipe',
  sprite: sprite,
  atlas: atlas,
  label: label,
  x: x,
  y: y,
  w: w,
  h: h,
);

CareDef tap(
  String sprite,
  String atlas,
  String label,
  double x,
  double y,
  double w,
  double h,
) => CareDef(
  type: 'tap',
  sprite: sprite,
  atlas: atlas,
  label: label,
  x: x,
  y: y,
  w: w,
  h: h,
);

List<RoomItem> makeItems(
  List<List<dynamic>> groups, [
  String defaultAtlas = 'OBJECT_ATLAS',
]) {
  final specs = <Map<String, dynamic>>[];
  for (final g in groups) {
    final sprite = g[0] as String;
    final targetId = g[1] as String;
    final count = g.length > 2 ? g[2] as int : 1;
    final atlas = g.length > 3 ? g[3] as String : defaultAtlas;
    for (int c = 0; c < count; c++) {
      specs.add({'sprite': sprite, 'target': targetId, 'atlas': atlas});
    }
  }
  final scale = specs.length >= 15
      ? 0.7
      : specs.length >= 12
      ? 0.76
      : specs.length >= 9
      ? 0.84
      : 0.94;
  final items = <RoomItem>[];
  for (int i = 0; i < specs.length; i++) {
    final s = specs[i];
    final xy = GRID[i % GRID.length];
    items.add(
      RoomItem(
        id: '${s['sprite']}-${i + 1}',
        sprite: s['sprite'] as String,
        target: s['target'] as String,
        atlas: s['atlas'] as String,
        x: xy[0].toDouble(),
        y: xy[1].toDouble(),
        rotation: ((i % 5) - 2) * 0.08,
        scale: scale,
      ),
    );
  }
  return items;
}

Room room({
  required String id,
  required String world,
  required String name,
  required String shortName,
  required String assetKey,
  required List<TargetDef> targets,
  required List<List<dynamic>> groups,
  String? atlas,
  List<CareDef> care = const [],
  QuickDef? quick,
}) => Room(
  id: id,
  world: world,
  name: name,
  shortName: shortName,
  assetKey: assetKey,
  targets: targets,
  items: makeItems(groups, atlas ?? 'OBJECT_ATLAS'),
  care: care,
  quick: quick,
);

final ROOMS = <Room>[
  room(
    id: 'bedroom',
    world: 'HOME',
    name: 'Cozy Bedroom',
    shortName: 'Bedroom',
    assetKey: 'ROOM_BEDROOM_BG',
    targets: [
      target('laundry_basket', 'Clothes'),
      target('book_crate', 'Books'),
      target('toy_box', 'Toys'),
      target('trash_bin', 'Trash'),
      target('bed_stack', 'Bed', 'TARGET_HOME_ATLAS'),
    ],
    groups: [
      ['shirt', 'laundry_basket'],
      ['sock', 'laundry_basket'],
      ['book', 'book_crate'],
      ['teddy', 'toy_box'],
      ['candy_wrapper', 'trash_bin'],
      ['pillow', 'bed_stack', 1, 'OBJECT_HOME_ATLAS'],
      ['blanket', 'bed_stack', 1, 'OBJECT_HOME_ATLAS'],
    ],
    quick: QuickDef(28, 44),
  ),
  room(
    id: 'living',
    world: 'HOME',
    name: 'Sunny Living Room',
    shortName: 'Living Room',
    assetKey: 'ROOM_LIVING_BG',
    targets: [
      target('sofa', 'Sofa'),
      target('book_crate', 'Books'),
      target('toy_box', 'Toys'),
      target('dish_tray', 'Dishes'),
      target('media_drawer', 'Media', 'TARGET_HOME_ATLAS'),
      target('trash_bin', 'Trash'),
    ],
    groups: [
      ['cushion', 'sofa', 2],
      ['magazine', 'book_crate', 2],
      ['toy_blocks', 'toy_box'],
      ['cup', 'dish_tray'],
      ['remote', 'media_drawer', 2, 'OBJECT_HOME_ATLAS'],
      ['snack_wrapper', 'trash_bin'],
    ],
    care: [
      swipe(
        'coffee_ring',
        'CLEANING_STAIN_ATLAS',
        'Wipe the table',
        0.63,
        0.43,
      ),
    ],
    quick: QuickDef(38, 58),
  ),
  room(
    id: 'kitchen',
    world: 'HOME',
    name: 'Little Kitchen',
    shortName: 'Kitchen',
    assetKey: 'ROOM_KITCHEN_BG',
    targets: [
      target('sink', 'Sink'),
      target('fridge', 'Fridge'),
      target('utensil_cup', 'Tools'),
      target('kitchen_cabinet', 'Cabinet', 'TARGET_HOME_ATLAS'),
      target('fruit_basket', 'Fruit', 'TARGET_HOME_ATLAS'),
      target('trash_bin', 'Trash'),
    ],
    groups: [
      ['plate', 'sink', 2],
      ['mug', 'sink'],
      ['apple', 'fruit_basket', 2],
      ['milk_carton', 'fridge', 2],
      ['spoon', 'utensil_cup'],
      ['frying_pan', 'kitchen_cabinet', 1, 'OBJECT_HOME_ATLAS'],
      ['cutting_board', 'kitchen_cabinet', 1, 'OBJECT_HOME_ATLAS'],
      ['snack_wrapper', 'trash_bin'],
    ],
    care: [
      swipe(
        'grease_mark',
        'CLEANING_STAIN_ATLAS',
        'Scrub the counter',
        0.43,
        0.42,
      ),
    ],
    quick: QuickDef(48, 72),
  ),
  room(
    id: 'bathroom',
    world: 'HOME',
    name: 'Bubble Bathroom',
    shortName: 'Bathroom',
    assetKey: 'ROOM_BATHROOM_BG',
    targets: [
      target('laundry_basket', 'Laundry'),
      target('bath_shelf', 'Shelf'),
      target('bath_toy_basket', 'Bath Toys'),
      target('bath_caddy', 'Caddy', 'TARGET_HOME_ATLAS'),
      target('linen_basket', 'Linen', 'TARGET_HOME_ATLAS'),
      target('trash_bin', 'Trash'),
    ],
    groups: [
      ['towel', 'linen_basket', 2],
      ['rubber_duck', 'bath_toy_basket', 2],
      ['toothbrush', 'bath_shelf', 2],
      ['soap_bottle', 'bath_caddy'],
      ['shampoo', 'bath_caddy', 1, 'OBJECT_HOME_ATLAS'],
      ['hairbrush', 'bath_shelf', 1, 'OBJECT_HOME_ATLAS'],
      ['tissue', 'trash_bin'],
      ['slipper', 'laundry_basket'],
    ],
    care: [
      swipe('soap_scum', 'CLEANING_STAIN_ATLAS', 'Wipe the tub', 0.35, 0.55),
      swipe(
        'mirror_smudge',
        'CLEANING_STAIN_ATLAS',
        'Polish the mirror',
        0.56,
        0.27,
        0.3,
        0.22,
      ),
    ],
    quick: QuickDef(55, 82),
  ),
  room(
    id: 'balcony',
    world: 'HOME',
    name: 'Blooming Balcony',
    shortName: 'Balcony',
    assetKey: 'ROOM_BALCONY_BG',
    targets: [
      target('garden_crate', 'Garden'),
      target('plant_shelf', 'Plants', 'TARGET_HOME_ATLAS'),
      target('book_crate', 'Books'),
      target('laundry_basket', 'Cloth'),
      target('recycling_bin', 'Recycle', 'TARGET_HOME_ATLAS'),
      target('trash_bin', 'Trash'),
    ],
    groups: [
      ['flower_pot', 'plant_shelf', 2],
      ['garden_tools', 'garden_crate', 2],
      ['book', 'book_crate', 2],
      ['towel', 'laundry_basket', 2],
      ['newspaper', 'recycling_bin', 2, 'OBJECT_HOME_ATLAS'],
      ['empty_can', 'recycling_bin', 1, 'OBJECT_HOME_ATLAS'],
      ['snack_wrapper', 'trash_bin'],
    ],
    care: [
      swipe('leaf_pile', 'CARE_ATLAS', 'Sweep the leaves', 0.45, 0.69),
      tap(
        'wilted_plant',
        'CARE_ATLAS',
        'Water the plant',
        0.52,
        0.45,
        0.28,
        0.34,
      ),
    ],
    quick: QuickDef(58, 86),
  ),
  room(
    id: 'classroom',
    world: 'SCHOOL',
    name: 'Busy Classroom',
    shortName: 'Classroom',
    assetKey: 'ROOM_CLASSROOM_BG',
    targets: [
      target('pencil_cup', 'Writing', 'TARGET_SCHOOL_ATLAS'),
      target('notebook_shelf', 'Books', 'TARGET_SCHOOL_ATLAS'),
      target('craft_drawer', 'Craft', 'TARGET_SCHOOL_ATLAS'),
      target('backpack_cubby', 'Bags', 'TARGET_SCHOOL_ATLAS'),
      target('lunch_cart', 'Lunch', 'TARGET_SCHOOL_ATLAS'),
      target('school_recycle', 'Recycle', 'TARGET_SCHOOL_ATLAS'),
    ],
    groups: [
      ['pencil_case', 'pencil_cup', 2],
      ['ruler', 'pencil_cup', 2],
      ['notebook', 'notebook_shelf', 2],
      ['eraser', 'craft_drawer', 2],
      ['glue_stick', 'craft_drawer'],
      ['backpack', 'backpack_cubby'],
      ['lunch_box', 'lunch_cart'],
      ['juice_carton', 'school_recycle'],
    ],
    atlas: 'OBJECT_SCHOOL_ATLAS',
    care: [
      swipe(
        'crumb_cluster',
        'CLEANING_DUST_ATLAS',
        'Brush away the crumbs',
        0.48,
        0.66,
      ),
    ],
    quick: QuickDef(62, 92),
  ),
  room(
    id: 'art',
    world: 'SCHOOL',
    name: 'Colorful Art Room',
    shortName: 'Art Room',
    assetKey: 'ROOM_ART_BG',
    targets: [
      target('brush_cup', 'Brushes', 'TARGET_EXTRA_ATLAS'),
      target('paint_drawer', 'Paint', 'TARGET_EXTRA_ATLAS'),
      target('canvas_rack', 'Canvas', 'TARGET_EXTRA_ATLAS'),
      target('paper_bin', 'Paper', 'TARGET_EXTRA_ATLAS'),
      target('notebook_shelf', 'Books', 'TARGET_SCHOOL_ATLAS'),
      target('school_recycle', 'Recycle', 'TARGET_SCHOOL_ATLAS'),
    ],
    groups: [
      ['paintbrush', 'brush_cup', 3],
      ['paint_tube', 'paint_drawer', 3],
      ['mini_canvas', 'canvas_rack', 2],
      ['paper_scrap', 'paper_bin', 2],
      ['sketchbook', 'notebook_shelf', 2],
      ['crayon_box', 'paint_drawer'],
      ['juice_carton', 'school_recycle', 1, 'OBJECT_SCHOOL_ATLAS'],
    ],
    atlas: 'OBJECT_EXTRA_ATLAS',
    care: [
      swipe(
        'paint_splash',
        'CLEANING_STAIN_ATLAS',
        'Scrub the paint',
        0.48,
        0.63,
      ),
      swipe('dust_patch', 'CLEANING_DUST_ATLAS', 'Dust the easel', 0.3, 0.42),
    ],
    quick: QuickDef(70, 102),
  ),
  room(
    id: 'science',
    world: 'SCHOOL',
    name: 'Curious Science Room',
    shortName: 'Science Room',
    assetKey: 'ROOM_SCIENCE_BG',
    targets: [
      target('science_cabinet', 'Glassware', 'TARGET_SCHOOL_ATLAS'),
      target('goggle_hook', 'Goggles', 'TARGET_SCHOOL_ATLAS'),
      target('model_shelf', 'Models', 'TARGET_SCHOOL_ATLAS'),
      target('notebook_shelf', 'Books', 'TARGET_SCHOOL_ATLAS'),
      target('craft_drawer', 'Tools', 'TARGET_SCHOOL_ATLAS'),
      target('school_recycle', 'Recycle', 'TARGET_SCHOOL_ATLAS'),
    ],
    groups: [
      ['safety_goggles', 'goggle_hook', 3],
      ['test_tube_rack', 'science_cabinet', 3],
      ['planet_model', 'model_shelf', 2],
      ['magnet', 'craft_drawer', 2],
      ['notebook', 'notebook_shelf', 2],
      ['ruler', 'craft_drawer'],
      ['juice_carton', 'school_recycle', 2],
    ],
    atlas: 'OBJECT_SCHOOL_ATLAS',
    care: [
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Polish the glass',
        0.57,
        0.39,
      ),
      swipe(
        'dust_patch',
        'CLEANING_DUST_ATLAS',
        'Dust the counter',
        0.42,
        0.63,
      ),
    ],
    quick: QuickDef(76, 110),
  ),
  room(
    id: 'hallway',
    world: 'SCHOOL',
    name: 'After-School Hallway',
    shortName: 'Hallway',
    assetKey: 'ROOM_HALLWAY_BG',
    targets: [
      target('backpack_cubby', 'Bags', 'TARGET_SCHOOL_ATLAS'),
      target('lunch_cart', 'Lunch', 'TARGET_SCHOOL_ATLAS'),
      target('coat_hook', 'Clothes', 'TARGET_SCHOOL_ATLAS'),
      target('key_board', 'Keys', 'TARGET_SCHOOL_ATLAS'),
      target('school_recycle', 'Recycle', 'TARGET_SCHOOL_ATLAS'),
    ],
    groups: [
      ['backpack', 'backpack_cubby', 4],
      ['lunch_box', 'lunch_cart', 3],
      ['scarf', 'coat_hook', 3],
      ['lost_key', 'key_board', 3],
      ['juice_carton', 'school_recycle', 3],
    ],
    atlas: 'OBJECT_SCHOOL_ATLAS',
    care: [
      swipe(
        'muddy_print',
        'CLEANING_STAIN_ATLAS',
        'Mop the footprints',
        0.5,
        0.67,
        0.38,
        0.24,
      ),
      swipe(
        'cobweb',
        'CLEANING_DUST_ATLAS',
        'Clear the cobweb',
        0.78,
        0.25,
        0.24,
        0.24,
      ),
    ],
    quick: QuickDef(82, 118),
  ),
  room(
    id: 'school-garden',
    world: 'SCHOOL',
    name: 'School Garden',
    shortName: 'School Garden',
    assetKey: 'ROOM_SCHOOL_GARDEN_BG',
    targets: [
      target('garden_crate', 'Tools', 'TARGET_SCHOOL_ATLAS'),
      target('plant_shelf', 'Seedlings', 'TARGET_HOME_ATLAS'),
      target('petal_compost', 'Compost', 'TARGET_EXTRA_ATLAS'),
      target('school_recycle', 'Recycle', 'TARGET_SCHOOL_ATLAS'),
      target('trash_bin', 'Trash'),
    ],
    groups: [
      ['seedling_pot', 'plant_shelf', 4],
      ['hand_trowel', 'garden_crate', 3],
      ['garden_marker', 'garden_crate', 3],
      ['dry_leaf', 'petal_compost', 3, 'OBJECT_ATLAS'],
      ['juice_carton', 'school_recycle', 2],
      ['candy_wrapper', 'trash_bin', 1, 'OBJECT_ATLAS'],
    ],
    atlas: 'OBJECT_SCHOOL_ATLAS',
    care: [
      swipe(
        'leaf_bits',
        'CLEANING_DUST_ATLAS',
        'Sweep the path',
        0.48,
        0.68,
        0.38,
        0.24,
      ),
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Wipe the greenhouse',
        0.55,
        0.35,
      ),
    ],
    quick: QuickDef(86, 124),
  ),
  room(
    id: 'bakery',
    world: 'SHOP',
    name: 'Honeycomb Bakery',
    shortName: 'Bakery',
    assetKey: 'ROOM_BAKERY_BG',
    targets: [
      target('bread_basket', 'Bread', 'TARGET_SHOP_ATLAS'),
      target('pastry_case', 'Pastries', 'TARGET_SHOP_ATLAS'),
      target('oven_hook', 'Baking', 'TARGET_SHOP_ATLAS'),
      target('cash_drawer', 'Counter', 'TARGET_SHOP_ATLAS'),
      target('wrap_station', 'Wrap', 'TARGET_SHOP_ATLAS'),
      target('shop_recycle', 'Recycle', 'TARGET_SHOP_ATLAS'),
    ],
    groups: [
      ['bread_loaf', 'bread_basket', 4],
      ['croissant', 'pastry_case', 3],
      ['cake_slice', 'pastry_case', 2],
      ['oven_mitt', 'oven_hook', 2],
      ['receipt_roll', 'cash_drawer', 2],
      ['paper_bag', 'wrap_station', 2],
      ['menu_card', 'shop_recycle'],
    ],
    atlas: 'OBJECT_SHOP_ATLAS',
    care: [
      swipe(
        'crumb_cluster',
        'CLEANING_DUST_ATLAS',
        'Sweep the crumbs',
        0.46,
        0.68,
      ),
      swipe('grease_mark', 'CLEANING_STAIN_ATLAS', 'Wipe the oven', 0.65, 0.38),
    ],
    quick: QuickDef(88, 126),
  ),
  room(
    id: 'cafe',
    world: 'SHOP',
    name: 'Lavender Café',
    shortName: 'Café',
    assetKey: 'ROOM_CAFE_BG',
    targets: [
      target('cup_rack', 'Cups', 'TARGET_SHOP_ATLAS'),
      target('tea_shelf', 'Tea', 'TARGET_SHOP_ATLAS'),
      target('sugar_caddy', 'Sugar', 'TARGET_SHOP_ATLAS'),
      target('menu_stand', 'Menus', 'TARGET_HOTEL_ATLAS'),
      target('cash_drawer', 'Counter', 'TARGET_SHOP_ATLAS'),
      target('shop_recycle', 'Recycle', 'TARGET_SHOP_ATLAS'),
    ],
    groups: [
      ['coffee_cup', 'cup_rack', 4],
      ['tea_pot', 'tea_shelf', 3],
      ['sugar_jar', 'sugar_caddy', 3],
      ['menu_card', 'menu_stand', 2],
      ['receipt_roll', 'cash_drawer', 2],
      ['paper_bag', 'shop_recycle', 2],
    ],
    atlas: 'OBJECT_SHOP_ATLAS',
    care: [
      swipe(
        'coffee_ring',
        'CLEANING_STAIN_ATLAS',
        'Wipe the tables',
        0.34,
        0.49,
      ),
      swipe('juice_spill', 'CLEANING_STAIN_ATLAS', 'Mop the spill', 0.6, 0.68),
    ],
    quick: QuickDef(92, 132),
  ),
  room(
    id: 'toy-shop',
    world: 'SHOP',
    name: 'Moonbeam Toy Shop',
    shortName: 'Toy Shop',
    assetKey: 'ROOM_TOYSHOP_BG',
    targets: [
      target('train_shelf', 'Trains', 'TARGET_EXTRA_ATLAS'),
      target('game_shelf', 'Games', 'TARGET_EXTRA_ATLAS'),
      target('ball_basket', 'Balls', 'TARGET_EXTRA_ATLAS'),
      target('doll_cradle', 'Dolls', 'TARGET_EXTRA_ATLAS'),
      target('toy_display', 'Display', 'TARGET_SHOP_ATLAS'),
      target('cash_drawer', 'Counter', 'TARGET_SHOP_ATLAS'),
    ],
    groups: [
      ['toy_train', 'train_shelf', 3, 'OBJECT_EXTRA_ATLAS'],
      ['yo_yo', 'game_shelf', 2, 'OBJECT_EXTRA_ATLAS'],
      ['puzzle_box', 'game_shelf', 2, 'OBJECT_EXTRA_ATLAS'],
      ['rubber_ball', 'ball_basket', 3, 'OBJECT_EXTRA_ATLAS'],
      ['rag_doll', 'doll_cradle', 2, 'OBJECT_EXTRA_ATLAS'],
      ['toy_robot', 'toy_display', 2],
      ['wooden_plane', 'toy_display'],
      ['receipt_roll', 'cash_drawer'],
    ],
    atlas: 'OBJECT_SHOP_ATLAS',
    care: [
      swipe(
        'shelf_dust',
        'CARE_EXTRA_ATLAS',
        'Dust the displays',
        0.5,
        0.43,
        0.38,
        0.2,
      ),
      swipe('lint_patch', 'CLEANING_DUST_ATLAS', 'Brush the rug', 0.48, 0.69),
    ],
    quick: QuickDef(94, 136),
  ),
  room(
    id: 'book-shop',
    world: 'SHOP',
    name: 'Willow Book Shop',
    shortName: 'Book Shop',
    assetKey: 'ROOM_BOOKSHOP_BG',
    targets: [
      target('book_shelf', 'Books', 'TARGET_SHOP_ATLAS'),
      target('bookmark_jar', 'Bookmarks', 'TARGET_SHOP_ATLAS'),
      target('cash_drawer', 'Counter', 'TARGET_SHOP_ATLAS'),
      target('wrap_station', 'Wrap', 'TARGET_SHOP_ATLAS'),
      target('shop_recycle', 'Recycle', 'TARGET_SHOP_ATLAS'),
    ],
    groups: [
      ['storybook', 'book_shelf', 6],
      ['bookmark', 'bookmark_jar', 4],
      ['cash_drawer_key', 'cash_drawer', 2],
      ['receipt_roll', 'cash_drawer', 2],
      ['paper_bag', 'wrap_station'],
      ['menu_card', 'shop_recycle'],
    ],
    atlas: 'OBJECT_SHOP_ATLAS',
    care: [
      swipe(
        'dust_patch',
        'CLEANING_DUST_ATLAS',
        'Dust the shelves',
        0.48,
        0.43,
        0.4,
        0.2,
      ),
      swipe(
        'cobweb',
        'CLEANING_DUST_ATLAS',
        'Clear the high corner',
        0.76,
        0.24,
        0.23,
        0.23,
      ),
    ],
    quick: QuickDef(96, 140),
  ),
  room(
    id: 'flower-shop',
    world: 'SHOP',
    name: 'Petal Flower Shop',
    shortName: 'Flower Shop',
    assetKey: 'ROOM_FLOWER_BG',
    targets: [
      target('flower_bucket', 'Flowers', 'TARGET_EXTRA_ATLAS'),
      target('ribbon_drawer', 'Ribbons', 'TARGET_EXTRA_ATLAS'),
      target('glove_hook', 'Gloves', 'TARGET_EXTRA_ATLAS'),
      target('vase_shelf', 'Vases', 'TARGET_EXTRA_ATLAS'),
      target('wrap_station', 'Wrap', 'TARGET_SHOP_ATLAS'),
      target('petal_compost', 'Compost', 'TARGET_EXTRA_ATLAS'),
    ],
    groups: [
      ['bouquet', 'flower_bucket', 4, 'OBJECT_EXTRA_ATLAS'],
      ['seed_packet', 'flower_bucket', 2, 'OBJECT_EXTRA_ATLAS'],
      ['ribbon_roll', 'ribbon_drawer', 2, 'OBJECT_EXTRA_ATLAS'],
      ['garden_gloves', 'glove_hook', 2, 'OBJECT_EXTRA_ATLAS'],
      ['glass_vase', 'vase_shelf', 2, 'OBJECT_EXTRA_ATLAS'],
      ['flower_wrap', 'wrap_station', 2],
      ['dry_petals', 'petal_compost', 2, 'OBJECT_EXTRA_ATLAS'],
    ],
    atlas: 'OBJECT_SHOP_ATLAS',
    care: [
      swipe(
        'petal_scatter',
        'CARE_EXTRA_ATLAS',
        'Sweep the petals',
        0.48,
        0.68,
        0.38,
        0.23,
      ),
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Polish the vases',
        0.6,
        0.42,
      ),
    ],
    quick: QuickDef(98, 142),
  ),
  room(
    id: 'guest-room',
    world: 'HOTEL',
    name: 'Boutique Guest Room',
    shortName: 'Guest Room',
    assetKey: 'ROOM_HOTEL_GUEST_BG',
    targets: [
      target('luggage_rack', 'Luggage', 'TARGET_HOTEL_ATLAS'),
      target('key_cubby', 'Keys', 'TARGET_HOTEL_ATLAS'),
      target('towel_cart', 'Towels', 'TARGET_HOTEL_ATLAS'),
      target('robe_closet', 'Robes', 'TARGET_HOTEL_ATLAS'),
      target('service_tray', 'Service', 'TARGET_HOTEL_ATLAS'),
      target('hotel_recycle', 'Recycle', 'TARGET_HOTEL_ATLAS'),
    ],
    groups: [
      ['suitcase', 'luggage_rack', 3],
      ['room_key', 'key_cubby', 2],
      ['guest_towel', 'towel_cart', 4],
      ['bathrobe', 'robe_closet', 2],
      ['coffee_tray', 'service_tray', 2],
      ['luggage_tag', 'luggage_rack'],
      ['sunscreen', 'hotel_recycle'],
      ['paper_bag', 'hotel_recycle', 1, 'OBJECT_SHOP_ATLAS'],
    ],
    atlas: 'OBJECT_HOTEL_ATLAS',
    care: [
      swipe(
        'mirror_smudge',
        'CLEANING_STAIN_ATLAS',
        'Polish the mirror',
        0.63,
        0.32,
      ),
      swipe(
        'lint_patch',
        'CLEANING_DUST_ATLAS',
        'Brush the carpet',
        0.46,
        0.68,
      ),
    ],
    quick: QuickDef(100, 146),
  ),
  room(
    id: 'hotel-lobby',
    world: 'HOTEL',
    name: 'Golden Hotel Lobby',
    shortName: 'Hotel Lobby',
    assetKey: 'ROOM_HOTEL_LOBBY_BG',
    targets: [
      target('luggage_rack', 'Luggage', 'TARGET_HOTEL_ATLAS'),
      target('key_cubby', 'Keys', 'TARGET_HOTEL_ATLAS'),
      target('bell_desk', 'Desk', 'TARGET_HOTEL_ATLAS'),
      target('service_tray', 'Service', 'TARGET_HOTEL_ATLAS'),
      target('garden_store', 'Decor', 'TARGET_HOTEL_ATLAS'),
      target('hotel_recycle', 'Recycle', 'TARGET_HOTEL_ATLAS'),
    ],
    groups: [
      ['suitcase', 'luggage_rack', 4],
      ['room_key', 'key_cubby', 3],
      ['bell', 'bell_desk', 2],
      ['luggage_tag', 'bell_desk', 2],
      ['coffee_tray', 'service_tray', 2],
      ['garden_lantern', 'garden_store', 2],
      ['paper_bag', 'hotel_recycle', 1, 'OBJECT_SHOP_ATLAS'],
    ],
    atlas: 'OBJECT_HOTEL_ATLAS',
    care: [
      swipe(
        'muddy_print',
        'CLEANING_STAIN_ATLAS',
        'Mop the entry',
        0.48,
        0.68,
        0.4,
        0.24,
      ),
      swipe('dust_patch', 'CLEANING_DUST_ATLAS', 'Dust the desk', 0.5, 0.42),
    ],
    quick: QuickDef(104, 150),
  ),
  room(
    id: 'restaurant',
    world: 'HOTEL',
    name: 'Garden Restaurant',
    shortName: 'Restaurant',
    assetKey: 'ROOM_RESTAURANT_BG',
    targets: [
      target('dish_station', 'Dishes', 'TARGET_HOTEL_ATLAS'),
      target('linen_station', 'Linen', 'TARGET_HOTEL_ATLAS'),
      target('menu_stand', 'Menus', 'TARGET_HOTEL_ATLAS'),
      target('service_tray', 'Service', 'TARGET_HOTEL_ATLAS'),
      target('hotel_recycle', 'Recycle', 'TARGET_HOTEL_ATLAS'),
    ],
    groups: [
      ['dinner_plate', 'dish_station', 4],
      ['wine_glass', 'dish_station', 3],
      ['napkin', 'linen_station', 4],
      ['menu_folder', 'menu_stand', 2],
      ['room_service_cover', 'service_tray', 2],
      ['coffee_tray', 'service_tray'],
    ],
    atlas: 'OBJECT_HOTEL_ATLAS',
    care: [
      swipe(
        'coffee_ring',
        'CLEANING_STAIN_ATLAS',
        'Wipe the tables',
        0.35,
        0.45,
      ),
      swipe(
        'grease_mark',
        'CLEANING_STAIN_ATLAS',
        'Polish the buffet',
        0.65,
        0.39,
      ),
      swipe(
        'crumb_cluster',
        'CLEANING_DUST_ATLAS',
        'Sweep the crumbs',
        0.5,
        0.69,
      ),
    ],
    quick: QuickDef(108, 156),
  ),
  room(
    id: 'hotel-garden',
    world: 'HOTEL',
    name: 'Hotel Courtyard',
    shortName: 'Hotel Garden',
    assetKey: 'ROOM_HOTEL_GARDEN_BG',
    targets: [
      target('garden_store', 'Lanterns', 'TARGET_HOTEL_ATLAS'),
      target('garden_crate', 'Tools', 'TARGET_SCHOOL_ATLAS'),
      target('petal_compost', 'Compost', 'TARGET_EXTRA_ATLAS'),
      target('towel_cart', 'Linen', 'TARGET_HOTEL_ATLAS'),
      target('hotel_recycle', 'Recycle', 'TARGET_HOTEL_ATLAS'),
    ],
    groups: [
      ['garden_lantern', 'garden_store', 4],
      ['hand_trowel', 'garden_crate', 3, 'OBJECT_SCHOOL_ATLAS'],
      ['garden_marker', 'garden_crate', 2, 'OBJECT_SCHOOL_ATLAS'],
      ['dry_leaf', 'petal_compost', 4, 'OBJECT_ATLAS'],
      ['guest_towel', 'towel_cart', 2],
      ['empty_can', 'hotel_recycle', 1, 'OBJECT_HOME_ATLAS'],
    ],
    atlas: 'OBJECT_HOTEL_ATLAS',
    care: [
      swipe(
        'leaf_bits',
        'CLEANING_DUST_ATLAS',
        'Sweep the paths',
        0.47,
        0.68,
        0.4,
        0.24,
      ),
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Polish the fountain',
        0.52,
        0.38,
      ),
      swipe(
        'cobweb',
        'CLEANING_DUST_ATLAS',
        'Clear the arch',
        0.78,
        0.25,
        0.22,
        0.22,
      ),
    ],
    quick: QuickDef(112, 162),
  ),
  room(
    id: 'pool',
    world: 'HOTEL',
    name: 'Sunshine Pool Area',
    shortName: 'Pool Area',
    assetKey: 'ROOM_POOL_BG',
    targets: [
      target('pool_basket', 'Pool Gear', 'TARGET_HOTEL_ATLAS'),
      target('towel_cart', 'Towels', 'TARGET_HOTEL_ATLAS'),
      target('shoe_rack', 'Sandals', 'TARGET_HOME_ATLAS'),
      target('garden_store', 'Care', 'TARGET_HOTEL_ATLAS'),
      target('hotel_recycle', 'Recycle', 'TARGET_HOTEL_ATLAS'),
    ],
    groups: [
      ['pool_float', 'pool_basket', 4],
      ['swim_goggles', 'pool_basket', 3],
      ['guest_towel', 'towel_cart', 4],
      ['flip_flops', 'shoe_rack', 2],
      ['sunscreen', 'garden_store', 2],
      ['empty_can', 'hotel_recycle', 1, 'OBJECT_HOME_ATLAS'],
    ],
    atlas: 'OBJECT_HOTEL_ATLAS',
    care: [
      swipe(
        'sand_scatter',
        'CLEANING_DUST_ATLAS',
        'Sweep the deck',
        0.45,
        0.68,
        0.42,
        0.25,
      ),
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Polish the loungers',
        0.62,
        0.43,
      ),
      swipe(
        'shallow_puddle',
        'CLEANING_WATER_ATLAS',
        'Dry the puddle',
        0.35,
        0.58,
      ),
    ],
    quick: QuickDef(116, 168),
  ),
  room(
    id: 'pet-clinic',
    world: 'TOWN',
    name: 'Paws & Petals Clinic',
    shortName: 'Pet Clinic',
    assetKey: 'ROOM_PET_CLINIC_BG',
    targets: [
      target('pet_cubby', 'Carriers', 'TARGET_TOWN_ATLAS'),
      target('clinic_drawer', 'Clinic', 'TARGET_TOWN_ATLAS'),
      target('pet_bowl_shelf', 'Bowls', 'TARGET_TOWN_ATLAS'),
      target('linen_basket', 'Linen', 'TARGET_HOME_ATLAS'),
      target('hotel_recycle', 'Recycle', 'TARGET_HOTEL_ATLAS'),
    ],
    groups: [
      ['pet_carrier', 'pet_cubby', 3],
      ['stethoscope', 'clinic_drawer', 3],
      ['bandage_roll', 'linen_basket', 3],
      ['pet_bowl', 'pet_bowl_shelf', 3],
      ['medicine_box', 'clinic_drawer', 2],
      ['tissue', 'hotel_recycle', 2, 'OBJECT_ATLAS'],
    ],
    atlas: 'OBJECT_TOWN_ATLAS',
    care: [
      swipe(
        'lint_patch',
        'CLEANING_DUST_ATLAS',
        'Brush the pet beds',
        0.38,
        0.61,
      ),
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Polish the table',
        0.58,
        0.39,
      ),
      swipe(
        'dust_patch',
        'CLEANING_DUST_ATLAS',
        'Dust the cabinet',
        0.73,
        0.32,
      ),
    ],
    quick: QuickDef(120, 174),
  ),
  room(
    id: 'laundromat',
    world: 'TOWN',
    name: 'Bubble Basket Laundry',
    shortName: 'Laundromat',
    assetKey: 'ROOM_LAUNDROMAT_BG',
    targets: [
      target('washer', 'Wash', 'TARGET_TOWN_ATLAS'),
      target('dryer_basket', 'Fold', 'TARGET_TOWN_ATLAS'),
      target('ironing_board', 'Iron', 'TARGET_TOWN_ATLAS'),
      target('lost_found', 'Lost & Found', 'TARGET_TOWN_ATLAS'),
      target('cup_recycle', 'Recycle', 'TARGET_TOWN_ATLAS'),
    ],
    groups: [
      ['laundry_detergent', 'washer', 3],
      ['folded_sheet', 'dryer_basket', 3],
      ['clothespin_basket', 'dryer_basket', 3],
      ['steam_iron', 'ironing_board', 2],
      ['lost_sock', 'lost_found', 3],
      ['empty_can', 'cup_recycle', 2, 'OBJECT_HOME_ATLAS'],
    ],
    atlas: 'OBJECT_TOWN_ATLAS',
    care: [
      swipe('soap_scum', 'CLEANING_STAIN_ATLAS', 'Wipe the washers', 0.48, 0.4),
      swipe('lint_patch', 'CLEANING_DUST_ATLAS', 'Clear the lint', 0.62, 0.63),
      swipe(
        'shallow_puddle',
        'CLEANING_WATER_ATLAS',
        'Dry the floor',
        0.34,
        0.7,
      ),
    ],
    quick: QuickDef(124, 180),
  ),
  room(
    id: 'train-station',
    world: 'TOWN',
    name: 'Clover Train Station',
    shortName: 'Train Station',
    assetKey: 'ROOM_TRAIN_STATION_BG',
    targets: [
      target('ticket_booth', 'Tickets', 'TARGET_TOWN_ATLAS'),
      target('map_rack', 'Maps', 'TARGET_TOWN_ATLAS'),
      target('station_store', 'Station', 'TARGET_TOWN_ATLAS'),
      target('luggage_rack', 'Luggage', 'TARGET_HOTEL_ATLAS'),
      target('lost_found', 'Lost & Found', 'TARGET_TOWN_ATLAS'),
      target('cup_recycle', 'Recycle', 'TARGET_TOWN_ATLAS'),
    ],
    groups: [
      ['train_ticket', 'ticket_booth', 4],
      ['travel_map', 'map_rack', 3],
      ['conductor_cap', 'lost_found', 2],
      ['platform_lantern', 'station_store', 2],
      ['suitcase', 'luggage_rack', 3, 'OBJECT_HOTEL_ATLAS'],
      ['empty_can', 'cup_recycle', 2, 'OBJECT_HOME_ATLAS'],
    ],
    atlas: 'OBJECT_TOWN_ATLAS',
    care: [
      swipe(
        'soot_mark',
        'CLEANING_DUST_ATLAS',
        'Scrub the platform dust',
        0.48,
        0.68,
        0.42,
        0.24,
      ),
      swipe(
        'mirror_smudge',
        'CLEANING_STAIN_ATLAS',
        'Polish the ticket window',
        0.56,
        0.34,
      ),
      swipe(
        'crumb_cluster',
        'CLEANING_DUST_ATLAS',
        'Sweep the waiting room',
        0.33,
        0.59,
      ),
    ],
    quick: QuickDef(128, 186),
  ),
  room(
    id: 'cinema',
    world: 'TOWN',
    name: 'Starlight Cinema',
    shortName: 'Cinema',
    assetKey: 'ROOM_CINEMA_BG',
    targets: [
      target('snack_counter', 'Snacks', 'TARGET_TOWN_ATLAS'),
      target('film_cabinet', 'Films', 'TARGET_TOWN_ATLAS'),
      target('glasses_bin', 'Glasses', 'TARGET_TOWN_ATLAS'),
      target('ticket_booth', 'Tickets', 'TARGET_TOWN_ATLAS'),
      target('cup_recycle', 'Recycle', 'TARGET_TOWN_ATLAS'),
    ],
    groups: [
      ['popcorn_box', 'snack_counter', 4],
      ['film_reel', 'film_cabinet', 3],
      ['cinema_glasses', 'glasses_bin', 3],
      ['soda_cup', 'cup_recycle', 3],
      ['train_ticket', 'ticket_booth', 2],
      ['snack_wrapper', 'cup_recycle', 1, 'OBJECT_ATLAS'],
    ],
    atlas: 'OBJECT_TOWN_ATLAS',
    care: [
      swipe(
        'crumb_cluster',
        'CLEANING_DUST_ATLAS',
        'Sweep the popcorn',
        0.48,
        0.68,
        0.42,
        0.24,
      ),
      swipe(
        'juice_spill',
        'CLEANING_STAIN_ATLAS',
        'Mop the soda spill',
        0.68,
        0.6,
        0.24,
        0.2,
      ),
      swipe(
        'coffee_ring',
        'CLEANING_STAIN_ATLAS',
        'Wipe the counter',
        0.55,
        0.4,
      ),
    ],
    quick: QuickDef(132, 192),
  ),
  room(
    id: 'town-greenhouse',
    world: 'TOWN',
    name: 'Community Greenhouse',
    shortName: 'Greenhouse',
    assetKey: 'ROOM_TOWN_GREENHOUSE_BG',
    targets: [
      target('seed_bench', 'Seedlings', 'TARGET_TOWN_ATLAS'),
      target('greenhouse_tools', 'Tools', 'TARGET_TOWN_ATLAS'),
      target('garden_crate', 'Garden', 'TARGET_SCHOOL_ATLAS'),
      target('petal_compost', 'Compost', 'TARGET_EXTRA_ATLAS'),
      target('cup_recycle', 'Recycle', 'TARGET_TOWN_ATLAS'),
    ],
    groups: [
      ['seed_tray', 'seed_bench', 4],
      ['pruning_shears', 'greenhouse_tools', 3],
      ['hand_trowel', 'garden_crate', 3, 'OBJECT_SCHOOL_ATLAS'],
      ['seedling_pot', 'seed_bench', 3, 'OBJECT_SCHOOL_ATLAS'],
      ['empty_can', 'cup_recycle', 2, 'OBJECT_HOME_ATLAS'],
      ['dry_leaf', 'petal_compost', 1, 'OBJECT_ATLAS'],
    ],
    atlas: 'OBJECT_TOWN_ATLAS',
    care: [
      swipe(
        'leaf_bits',
        'CLEANING_DUST_ATLAS',
        'Sweep beneath the benches',
        0.48,
        0.69,
        0.42,
        0.24,
      ),
      swipe(
        'water_spots',
        'CLEANING_STAIN_ATLAS',
        'Polish the glass',
        0.58,
        0.32,
      ),
      swipe(
        'shallow_puddle',
        'CLEANING_WATER_ATLAS',
        'Dry the watering area',
        0.35,
        0.58,
      ),
    ],
    quick: QuickDef(136, 198),
  ),
];

void _applyHiddenClutter() {
  for (int ri = 0; ri < ROOMS.length; ri++) {
    final roomEntry = ROOMS[ri];
    final hiddenCount = ri < 2
        ? 0
        : ri < 5
        ? 1
        : ri < 10
        ? 2
        : ri < 20
        ? 3
        : 5;
    final count = hiddenCount.clamp(
      0,
      (roomEntry.items.length - 5).clamp(0, roomEntry.items.length),
    );
    if (count == 0) continue;
    final visibleCount = roomEntry.items.length - count;
    final hiddenItems = roomEntry.items.sublist(roomEntry.items.length - count);
    for (int hi = 0; hi < hiddenItems.length; hi++) {
      final entry = hiddenItems[hi];
      final coverIndex = ((hi + 1) * visibleCount / (count + 1)).round() - 1;
      final cover =
          roomEntry.items[coverIndex.clamp(0, roomEntry.items.length - 1)];
      entry.hidden = true;
      entry.hiddenUnder = cover.id;
      entry.x = cover.x;
      entry.y = cover.y;
      entry.rotation = cover.rotation * -0.7;
    }
  }
}

bool _hiddenClutterApplied = false;

void _ensureHiddenClutter() {
  if (_hiddenClutterApplied) return;
  _hiddenClutterApplied = true;
  _applyHiddenClutter();
}

final SKINS = [
  Skin('classic', 'Classic Apron', 0, 'BUNNY_SHEET'),
  Skin('berry', 'Berry Apron', 200, 'BUNNY_SHEET'),
  Skin('bear', 'Bear Hoodie', 350, 'BUNNY_SHEET'),
  Skin('panda', 'Panda Hoodie', 500, 'BUNNY_SHEET'),
  Skin('gardener', 'Gardener', 650, 'BUNNY_EXTRA_SHEET'),
  Skin('vet', 'Tiny Vet', 700, 'BUNNY_TOWN_SHEET'),
  Skin('student', 'Student', 800, 'BUNNY_WORLD_SHEET'),
  Skin('laundry', 'Laundry Day', 850, 'BUNNY_TOWN_SHEET'),
  Skin('wizard', 'Wizard', 900, 'BUNNY_EXTRA_SHEET'),
  Skin('chef', 'Chef', 1050, 'BUNNY_WORLD_SHEET'),
  Skin('conductor', 'Conductor', 1100, 'BUNNY_TOWN_SHEET'),
  Skin('bellhop', 'Bellhop', 1250, 'BUNNY_WORLD_SHEET'),
  Skin('movie_star', 'Movie Star', 1400, 'BUNNY_TOWN_SHEET'),
  Skin('princess', 'Princess', 1500, 'BUNNY_EXTRA_SHEET'),
  Skin('lifeguard', 'Lifeguard', 1750, 'BUNNY_WORLD_SHEET'),
  Skin('galaxy', 'Galaxy', 2200, 'BUNNY_EXTRA_SHEET'),
];

String skinSheet(String skinId) {
  for (final s in SKINS) {
    if (s.id == skinId) return s.sheet;
  }
  return 'BUNNY_SHEET';
}

List<TargetDef> roomTargets(Room roomEntry) => roomEntry.targets;

List<RoomItem> freshItems(Room roomEntry) {
  _ensureHiddenClutter();
  final rnd = Random();
  final items = roomEntry.items;
  final slots = _randomSlots(items.length, rnd);
  final copies = <RoomItem>[];
  final byId = <String, RoomItem>{};
  for (final entry in items) {
    final copy = RoomItem(
      id: entry.id,
      sprite: entry.sprite,
      target: entry.target,
      atlas: entry.atlas,
      x: 0,
      y: 0,
      rotation: entry.rotation,
      scale: entry.scale,
      hidden: entry.hidden,
      hiddenUnder: entry.hiddenUnder,
      revealed: !entry.hidden,
    );
    byId[entry.id] = copy;
    copies.add(copy);
  }
  for (int i = 0; i < copies.length; i++) {
    final copy = copies[i];
    if (copy.hidden && copy.hiddenUnder != null) {
      final cover = byId[copy.hiddenUnder!];
      if (cover != null) {
        copy.x = cover.x;
        copy.y = cover.y;
        copy.rotation = cover.rotation * -0.7;
        continue;
      }
    }
    final slot = slots[i];
    copy.x = slot[0];
    copy.y = slot[1];
    copy.rotation = ((i % 5) - 2) * 0.08 + (rnd.nextDouble() - 0.5) * 0.12;
  }
  return copies;
}

List<List<double>> _randomSlots(int count, Random rnd) {
  const cols = 6;
  const rows = 4;
  final pool = <List<double>>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final x = 0.1 + 0.8 * c / (cols - 1);
      final y = 0.5 + 0.36 * r / (rows - 1);
      pool.add([x, y]);
    }
  }
  pool.shuffle(rnd);
  final slots = <List<double>>[];
  for (int i = 0; i < count; i++) {
    final base = pool[i % pool.length];
    slots.add([
      (base[0] + (rnd.nextDouble() - 0.5) * 0.04).clamp(0.07, 0.93),
      (base[1] + (rnd.nextDouble() - 0.5) * 0.04).clamp(0.46, 0.9),
    ]);
  }
  return slots;
}
