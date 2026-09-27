import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 数据层：手机本地的 SQLite 数据库
///
/// 用 sqflite 这个库操作安卓系统自带的 SQLite。数据库文件落在 App 的私有目录
/// （`/data/data/com.xingho.today_todo/databases/`），其它应用读不到，卸载 App
/// 会一起删掉——这与 `PRD.md` 6.2「本期不做多端同步」的口径一致。
///
/// 这一层只干两件事：**建库建表**、**按 id 读写**。不碰界面、不弹提示。
/// 目前提供五个方法：查全部、新增、改完成状态、改标题与日期、删除。

const String _dbFileName = 'today_todo.db';
const int _dbVersion = 1;
const String _table = 'tasks';

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
    this.repeat,
  });

  final int? id;
  final String title;
  final DateTime date;
  final bool done;
  final String? repeat;

  /// 数据库里的一行 → Task。
  /// 两个转换点：日期存的是毫秒时间戳要转回 DateTime；SQLite 没有布尔类型，
  /// 用 0 / 1 表示，读出来要转成 true / false。
  factory Task.fromRow(Map<String, Object?> row) => Task(
        id: row['id'] as int?,
        title: row['title'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
        done: (row['done'] as int) == 1,
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
/// 代价记在这里：以后加字段时不能再靠改 [_dbVersion] 自动升级，
/// 那时要单独写一段「读旧版本号 → 手动迁移」的代码。
Future<Database> _open() async {
  final path = p.join(await getDatabasesPath(), _dbFileName);
  if (!await databaseExists(path)) {
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }
  return openDatabase(path);
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
      id     INTEGER PRIMARY KEY AUTOINCREMENT,
      title  TEXT    NOT NULL,
      date   INTEGER NOT NULL,
      done   INTEGER NOT NULL DEFAULT 0,
      repeat TEXT
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

/// 读出全部事项，交给界面渲染
Future<List<Task>> loadTasks() async {
  _db ??= await _open();
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
