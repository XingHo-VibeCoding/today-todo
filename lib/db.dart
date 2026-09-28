import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 数据层：手机本地的 SQLite 数据库
///
/// 用 sqflite 这个库操作安卓系统自带的 SQLite。数据库文件落在 App 的私有目录
/// （`/data/data/com.xingho.today_todo/databases/`），其它应用读不到，卸载 App
/// 会一起删掉——这与 `PRD.md` 6.2「本期不做多端同步」的口径一致。
///
/// 这一层干三件事：**建库建表（含老库结构升级）**、**按 id 读写**、
/// **按日清空已完成区**。不碰界面、不弹提示。
/// 对外提供五个方法：查全部、新增、改完成状态、改标题与日期、删除。

const String _dbFileName = 'today_todo.db';
const int _dbVersion = 1;
const String _table = 'tasks';

/// 存全局状态的小表（目前只放一个 key：上次清空时刻）。
const String _stateTable = 'app_state';

/// [_stateTable] 里「上次清空时刻」的 key。
const String _purgeKey = 'last_purge_at';

/// 已完成区的清空时刻（24 小时制的小时数）。
///
/// 4:00 之前完成的事项算前一天，留到下一个 4:00 才清掉——熬夜到两三点做完的
/// 事，第二天早上打开还能看见。改这个数就等于改「一天从几点开始」。
const int _purgeHour = 4;

/// 一条事项。
///
/// 字段按 `TECH_DESIGN.md` 2.5「存标题、日期、是否完成、周期类型」来定。
/// `repeat` 是给 F4 周期事项留的位置——F4 在本期范围内但不在 MVP 内，
/// 所以这一列现在恒为 null。
class Task {
  const Task({
    this.id,
    required this.title,
    required this.date,
    this.done = false,
    this.archived = false,
    this.repeat,
  });

  final int? id;
  final String title;
  final DateTime date;
  final bool done;

  /// 是否已被「凌晨 4:00 清空」归档。
  ///
  /// 归档不是删除：事项还在库里、`done` 也仍为真，只是不再出现在首页的
  /// 已完成区。见 [_purgeIfNeeded]。
  final bool archived;
  final String? repeat;

  /// 数据库里的一行 → Task。
  /// 两个转换点：日期存的是毫秒时间戳要转回 DateTime；SQLite 没有布尔类型，
  /// 用 0 / 1 表示，读出来要转成 true / false。
  factory Task.fromRow(Map<String, Object?> row) => Task(
        id: row['id'] as int?,
        title: row['title'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
        done: (row['done'] as int) == 1,
        archived: (row['archived'] as int) == 1,
        repeat: row['repeat'] as String?,
      );
}

/// 全局只开一次数据库连接，之后复用（`??=` 表示「没有才开」）
Database? _db;

/// 打开数据库文件。
///
/// **分两种情况，别合并成一句**：
///   - 文件不存在（首次安装）→ 带 `version` 打开，系统跑一遍 [_onCreate] 建表
///   - 文件已存在 → **不带 `version`** 直接打开
///
/// 第二种为什么不带 `version`：只要带了版本号，安卓就会去读库里的版本号；
/// 文件损坏读不到时，它会当成版本 0 并**自动删库重建**——用户的真实事项会被
/// 悄悄换成示例数据，界面上连一点异常都看不到。不带版本号打开就不会触发
/// 这套逻辑，坏文件会在第一次查询时抛出来，交给界面显示错误态。
///
/// 代价记在这里：**加字段时不能靠改 [_dbVersion] 自动升级**——老库走的是不带
/// 版本号的分支，`onUpgrade` 永远不会触发。新增的结构只能手动补，见 [_migrate]
/// （加 `archived` 列时已经用上了这条）。
Future<Database> _open() async {
  final path = p.join(await getDatabasesPath(), _dbFileName);
  if (!await databaseExists(path)) {
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }
  final db = await openDatabase(path);
  await _migrate(db);
  return db;
}

/// 给已经存在的老库补上后来新增的列与表。
///
/// 每步都是「先查、缺了才补」，所以重复执行安全，也不在乎用户中间跳过几个版本。
/// 这里**不去比库里的版本号**：[_open] 对老库是不带 `version` 打开的，
/// 那个数字压根没被维护过，拿它做判断不可靠。
Future<void> _migrate(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info($_table)');
  final names = columns.map((c) => c['name'] as String).toSet();
  if (!names.contains('archived')) {
    await db.execute(
      'ALTER TABLE $_table ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
    );
  }
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $_stateTable (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}

/// 建表；开发期版本再顺手写几条示例数据。
///
/// **只在数据库文件第一次被创建时执行一次**，之后每次打开 App 都不会再跑——
/// 这就是「数据能留下来」和「示例不会被重复插入」的实现方式。
///
/// 示例数据只在 debug 构建里种：它本来是为了开发时能立刻看到列表长什么样，
/// 不该出现在装给真实用户的包里——用户第一次打开不该看到 4 条不属于自己的事项。
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE $_table (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      title    TEXT    NOT NULL,
      date     INTEGER NOT NULL,
      done     INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      repeat   TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $_stateTable (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  if (kDebugMode) {
    for (final row in _seedRows()) {
      await db.insert(_table, row);
    }
  }
}

/// 开发期的示例数据（只在 debug 构建写入，见 [_onCreate]），与第 1 步界面里那 4 条一致——
/// 这样一对比就能看出「数据源换成数据库了，界面应该长得一模一样」。
/// 想清掉就在 App 里长按删除；想在模拟器里铺受控数据，用 `D:\dev\make_db.py`。
List<Map<String, Object?>> _seedRows() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  int ms(int offsetDays) =>
      today.add(Duration(days: offsetDays)).millisecondsSinceEpoch;

  return [
    {'title': '水卡充值', 'date': ms(-1), 'done': 0, 'repeat': null}, // 逾期未完成
    {'title': '交实验报告', 'date': ms(0), 'done': 0, 'repeat': null}, // 今天到期
    {'title': '洗衣服', 'date': ms(2), 'done': 0, 'repeat': null}, // 后天
    {'title': '倒垃圾', 'date': ms(-1), 'done': 1, 'repeat': null}, // 已完成
  ];
}

/// 当前时刻所属的「清空点」：今天 4:00，若还没到则是昨天 4:00。
DateTime _purgePoint(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, _purgeHour);
  return now.isBefore(today) ? today.subtract(const Duration(days: 1)) : today;
}

/// 跨过凌晨 4:00 就把已完成区清空，并记下这次的清空点。
///
/// 「清空」= 把 `done = 1` 的事项标成 `archived = 1`——不删行、也不改 `done`。
/// 首页的已完成区只显示 `done && !archived`，于是它们就不再出现。
///
/// **为什么不做成定时任务**：手机上的 App 没被打开就没有代码在跑，做不到准点
/// 执行。所以真正的时机是「下次打开时补做」——该不该清由存下来的清空点和当前
/// 时刻推算，与 App 何时被打开无关。
///
/// **首次运行**（库里没有清空点）直接清一次。这一步顺手把升级前就存在的已完成
/// 事项处理掉了——它们无从判断是哪天完成的，按旧数据处理。
Future<void> _purgeIfNeeded() async {
  final db = _db!;
  final point = _purgePoint(DateTime.now());

  final rows =
      await db.query(_stateTable, where: 'key = ?', whereArgs: [_purgeKey]);
  if (rows.isNotEmpty) {
    final last = DateTime.fromMillisecondsSinceEpoch(
      int.parse(rows.first['value'] as String),
    );
    if (!last.isBefore(point)) return; // 这个 4:00 已经清过了
  }

  await db.update(_table, {'archived': 1}, where: 'done = 1 AND archived = 0');
  await db.insert(
    _stateTable,
    {'key': _purgeKey, 'value': '${point.millisecondsSinceEpoch}'},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// 读出全部事项，交给界面渲染。
///
/// 读之前先跑一次 [_purgeIfNeeded]——清空不是定时任务，是「打开时才补做」。
Future<List<Task>> loadTasks() async {
  _db ??= await _open();
  await _purgeIfNeeded();
  final rows = await _db!.query(_table);
  return rows.map(Task.fromRow).toList();
}

/// 新增一条事项，返回新记录的 id。
///
/// 只收标题和日期——`done` 恒为未完成、`repeat` 恒为 null。
/// 这正对应 F3 第 1 条「只需填写标题即可保存，不设其它必填字段」。
Future<int> insertTask({required String title, required DateTime date}) async {
  _db ??= await _open();
  return _db!.insert(_table, {
    'title': title,
    'date': date.millisecondsSinceEpoch,
    'done': 0,
    'repeat': null,
  });
}

/// 改「是否完成」。撤销就是再用同一个方法写回原值。
///
/// 第 3 步只需要动这一列；改标题与日期见下面的 [updateTask]。
Future<void> setDone(int id, bool done) async {
  _db ??= await _open();
  await _db!.update(
    _table,
    {'done': done ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// 改一条已有事项的标题与日期。
///
/// 关键是**用 UPDATE，不是「删掉再插一条」**——那样会换掉 id，清单条数也会
/// 短暂变化。F3 第 3 条要求「修改后清单内立即显示新内容，且不产生新条目」，
/// 靠的就是这里只改字段、不动行数。
Future<void> updateTask(
  int id, {
  required String title,
  required DateTime date,
}) async {
  _db ??= await _open();
  await _db!.update(
    _table,
    {'title': title, 'date': date.millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// 删除一条事项。
///
/// 这里不做任何确认——「删除必须有二次确认」（AC-15）是交互层的事，
/// 由界面弹出对话框，用户点了确认才调到这里。
Future<void> deleteTask(int id) async {
  _db ??= await _open();
  await _db!.delete(_table, where: 'id = ?', whereArgs: [id]);
}
