import 'package:flutter/material.dart';

import 'db.dart';

/// 「今日待办」首页（阶段 3 · 第 4 步）
///
/// 第 4 步补齐 F3 的后半：**编辑** 与 **删除**。到此 MVP 的四件事（新增 / 编辑 /
/// 完成 / 删除）齐全。
///   - 新增 / 编辑：共用底部面板（`_TaskSheet`），只要求标题，标题为空不可保存，
///     日期默认「录入日的次日」且可改期；编辑走 UPDATE，不产生新条目
///   - 完成：点按**事项整条框**切换完成状态（不设勾选圆圈），完成后 3 秒内可撤销
///   - 删除：长按整条框 → 菜单 → 二次确认后才真正删
///
/// **手势分工**（实现见 `_TapToComplete`）：
///   点按 = 完成 ｜ 长按 = 编辑/删除菜单 ｜ 滑动 = 都不触发
/// 编辑与删除之所以放在长按里，是因为点按已被「完成」占用（AC-21），
/// 而在每条上加图标按钮会让首屏多出第五类元素（AC-2）。
///
/// 仍未做：通知（F2，不在本期 MVP 内）。右上「提醒设置」仍是看得见的占位。
void main() {
  runApp(const TodayTodoApp());
}

/* ============ 1. 日期显示 ============ */

const List<String> _weekNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 顶部那行「9月24日 周四」
String _todayLabel(DateTime now) =>
    '${now.month}月${now.day}日 ${_weekNames[now.weekday - 1]}';

/// 事项下面那行日期：今天 / 明天 / 昨天 / 9月26日
String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff =
      DateTime(date.year, date.month, date.day).difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  return '${date.month}月${date.day}日';
}

/* ============ 2. 界面 ============ */

class TodayTodoApp extends StatelessWidget {
  const TodayTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今日待办',
      // 关掉右上角的 DEBUG 角标：AC-2 要求首屏只有四类元素，角标算第五类
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 从数据库读出来的全部事项。null = 还没读出来——此时显示加载态，
  /// 免得先闪一下「未完成 · 0」再跳成真实条数。
  List<Task>? _tasks;

  /// 是否读库失败。异常本身只进日志（`debugPrint`），**不往界面上贴**——
  /// 用户看到 `DatabaseException(...)` 这种原文没有任何意义。
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 重新读库并重画。新增、完成、撤销之后都要走一遍。
  ///
  /// **读库失败不能让它抛出去**：抛出去在 debug 是红屏、在 release 是白屏，
  /// 用户看到的只是「打开就没东西」。这里接住、置上 [_loadFailed]，由界面给出
  /// 说明和「重试」——重试就是再跑一次本方法。异常详情写进日志，不上面。
  Future<void> _reload() async {
    try {
      final list = await loadTasks();
      if (mounted) {
        setState(() {
          _tasks = list;
          _loadFailed = false;
        });
      }
    } catch (e) {
      debugPrint('读库失败：$e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// 点按整条框 → 切换完成状态。
  ///
  /// 「完成后 3 秒内仍可见且可撤销」（AC-14）＝ 立刻写库并重画（该条移到已完成区，
  /// 仍在同一屏内），同时弹一条 3 秒的提示，上面挂「撤销」；撤销就是写回原值。
  /// 这里刻意不做「延迟 3 秒才写库」——那样中途杀掉 App 就会丢掉这次操作。
  Future<void> _toggleDone(Task task) async {
    if (task.id == null) return;
    final target = !task.done;
    await setDone(task.id!, target);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(target ? '已完成「${task.title}」' : '已恢复「${task.title}」'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await setDone(task.id!, task.done);
            await _reload();
          },
        ),
      ),
    );
  }

  /// 打开新增 / 编辑面板；拿到结果才写库。取消（返回 null）则什么都不做。
  ///
  /// 不传 [task] = 新增（INSERT）；传了 = 编辑同一条（UPDATE）。
  /// 两者共用面板，差别只在预填内容、标题栏文案，以及最后调哪个写库方法。
  Future<void> _openTaskSheet([Task? task]) async {
    final input = await showModalBottomSheet<_NewTaskInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TaskSheet(task: task),
    );
    if (input == null) return;
    if (task == null) {
      await insertTask(title: input.title, date: input.date);
    } else {
      await updateTask(task.id!, title: input.title, date: input.date);
    }
    await _reload();
  }

  /// 长按整条框 → 弹出「编辑 / 删除」菜单，选完再分发。
  ///
  /// 为什么编辑和删除要藏在长按里：点按已经被「完成」占用（AC-21）；
  /// 而在每条事项右边加两个图标按钮，会让首屏多出「操作按钮」这第五类元素，
  /// 与 AC-2「首屏只四类元素」冲突。长按是唯一既不冲突、又合安卓直觉的入口。
  Future<void> _showTaskMenu(Task task) async {
    final action = await showModalBottomSheet<_TaskAction>(
      context: context,
      builder: (_) => _TaskMenu(title: task.title),
    );
    if (action == _TaskAction.edit) {
      await _openTaskSheet(task);
    } else if (action == _TaskAction.delete) {
      await _confirmDelete(task);
    }
  }

  /// 删除前的二次确认（AC-15：删除必须有二次确认，不做无提示的直接删除）。
  /// 点「取消」或点面板外关掉 → 什么都不删。
  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条事项？'),
        content: Text(task.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteTask(task.id!);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final list = _tasks ?? const <Task>[];

    // 未完成：按日期升序 —— 越早到期的越靠前，逾期未完成的自然排最上面（AC-5）
    final pending = list.where((t) => !t.done).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // 已完成：永远排在未完成之后（AC-3）
    final done = list.where((t) => t.done).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          children: [
            _Header(now: DateTime.now()),
            if (_loadFailed)
              _StateView(
                title: '数据打不开',
                detail: '点「重试」再来一次；若一直失败，请重启 App 后再试。',
                actionLabel: '重试',
                onAction: _reload,
              )
            else if (_tasks == null)
              const _StateView(title: '正在读取…', busy: true)
            else if (list.isEmpty)
              const _StateView(
                title: '今天没有待办',
                detail: '点下面的「新增事项」记一条',
              )
            else ...[
              const SizedBox(height: 26),
              _SectionLabel('未完成 · ${pending.length}'),
              for (final t in pending)
                _TaskTile(
                  task: t,
                  onTap: () => _toggleDone(t),
                  onLongPress: () => _showTaskMenu(t),
                ),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 26),
                _SectionLabel('已完成 · ${done.length}'),
                for (final t in done)
                  _TaskTile(
                    task: t,
                    onTap: () => _toggleDone(t),
                    onLongPress: () => _showTaskMenu(t),
                  ),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: _AddBar(onPressed: () => _openTaskSheet()),
    );
  }
}

/// 列表区的三种「非数据」状态：加载中 / 空 / 读库失败。
///
/// 三种形状一样——居中一段主文案，可能再带一行说明和一个按钮——所以只写这一个
/// 组件，换字不换结构。它们都是**顶替**列表区，不是首屏新增的常驻元素，
/// 因此不违反 AC-2「首屏只四类元素」。
class _StateView extends StatelessWidget {
  const _StateView({
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 加载态：文案上方加一个转圈。
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 0),
      child: Column(
        children: [
          if (busy) ...[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFFA0A6B0)),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// ① 标题 + 当天日期 + 提醒设置入口
class _Header extends StatelessWidget {
  const _Header({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今日待办',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Color(0xFF1B1F24),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _todayLabel(now),
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        // 提醒设置入口：本步只是占位，点了没有反应（F2 不在本期 MVP 内）
        IconButton(
          onPressed: () {},
          tooltip: '提醒设置',
          iconSize: 22,
          color: const Color(0xFF6B7280),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }
}

/// ② 分组小标题：未完成 · 3 / 已完成 · 1
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

/// ③ 一条事项：标题 + 日期。已完成加删除线并整体变灰（AC-3）
///
/// 整条框就是完成按钮（AC-21）：不设勾选圆圈，外层的 [_TapToComplete] 负责
/// 「点按才算、滑了或按太久就作废」。长按同一个框则弹出编辑 / 删除菜单。
/// 8 dp 的间距挪到外面，免得点空隙也能触发。
class _TaskTile extends StatelessWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onLongPress,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = !task.done && task.date.isBefore(today);

    final titleColor =
        task.done ? const Color(0xFFA0A6B0) : const Color(0xFF1B1F24);
    final dateColor = overdue
        ? const Color(0xFFD97706)
        : (task.done ? const Color(0xFFBCC1C9) : const Color(0xFFA0A6B0));

    return _TapToComplete(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: task.done ? const Color(0xFFFAFBFC) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: task.done
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0A101828),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  decorationColor: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _dateLabel(task.date),
                style: TextStyle(
                  fontSize: 13,
                  color: dateColor,
                  fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ④ 新增入口：点开底部的新增面板
class _AddBar extends StatelessWidget {
  const _AddBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F8),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('新增事项'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============ 3. 点按判定（AC-21） ============ */

/// 整条框的手势判定：点按 = 完成，长按 = 编辑/删除菜单，滑动则两者都不触发。
///
/// **为什么不用 `InkWell` / `GestureDetector.onTap`**：
/// Flutter 自带的点击识别器容差是 18 dp（`kTouchSlop`），而 AC-21 要求位移超过
/// **10 dp** 就作废；它也不管你按了多久，而 AC-21 要求按住超过 **500 ms** 作废。
/// 两个数都比框架默认值更严，所以这里自己记下按下的时刻与坐标，抬手时各判一次。
///
/// 四种情形分别怎么走：
///   1. 正常点一下 → 位移 ≤ 10 dp 且时长 ≤ 500 ms → 执行完成
///   2. 长按够久 → 框架的 `onLongPress` 赢走手势，点按收到 cancel → 弹编辑/删除菜单
///   3. 滑动（位移超过框架的 18 dp）→ 手势被列表滚动接管，`onTapCancel` 触发 → 作废
///   4. 滑动幅度在 10～18 dp 之间 → 框架仍判为点击，但下面第二个判据会拦下 → 作废
///
/// 第 2 条不需要自己计时：框架的长按阈值 `kLongPressTimeout` 恰好就是 500 ms，
/// 与 AC-21 的界线是同一个数，所以长按与「按住太久不触发完成」天然一致。
class _TapToComplete extends StatefulWidget {
  const _TapToComplete({
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  @override
  State<_TapToComplete> createState() => _TapToCompleteState();
}

class _TapToCompleteState extends State<_TapToComplete> {
  /// AC-21：位移 > 10 dp 即作废
  static const double _maxDrift = 10;

  /// AC-21：按住 > 500 ms 即作废
  static const Duration _maxHold = Duration(milliseconds: 500);

  Offset? _downPos;
  DateTime? _downAt;
  bool _pressed = false;

  void _onTapDown(TapDownDetails d) {
    _downPos = d.localPosition;
    _downAt = DateTime.now();
    setState(() => _pressed = true);
  }

  void _reset() {
    _downPos = null;
    _downAt = null;
    if (_pressed) setState(() => _pressed = false);
  }

  /// 长按（框架默认 500 ms）→ 编辑 / 删除菜单，**不触发完成**。
  ///
  /// 这里补一次 [_reset]：框架在长按胜出时会先给点按识别器发 cancel（走
  /// `onTapCancel`），但两者先后顺序不作保证，自己再清一次更稳——
  /// 否则按下时那个缩放动画可能卡在 0.98 回不来。
  void _onLongPress() {
    _reset();
    widget.onLongPress();
  }

  void _onTapUp(TapUpDetails d) {
    final start = _downPos;
    final at = _downAt;
    _reset();
    if (start == null || at == null) return;

    final drifted = (d.localPosition - start).distance > _maxDrift;
    final held = DateTime.now().difference(at) > _maxHold;
    if (drifted || held) return; // 滑了、或按太久 → 作废

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque：整块矩形都接收点击，包括容器内没有文字的空白处
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _reset,
      onLongPress: _onLongPress,
      // 按下时轻微缩小，让「整条框都能点」这件事看得见
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

/* ============ 4. 新增面板（AC-10 / AC-11） ============ */

/// 面板填完的结果。面板自己不碰数据库，只把结果交回首页；
/// 新增和编辑都返回这个东西，首页再决定是 INSERT 还是 UPDATE。
class _NewTaskInput {
  const _NewTaskInput(this.title, this.date);

  final String title;
  final DateTime date;
}

/// 新增与编辑共用的底部面板：只有「标题」一个输入框，加一行可改期的日期。
///
/// 不设其它字段——对应 F3 第 1 条「不设其它必填字段」。
/// 传了 [task] 就是编辑：标题与日期预填原内容，标题栏写「编辑事项」；
/// 不传就是新增：标题空着，日期默认「录入日的次日」。
class _TaskSheet extends StatefulWidget {
  const _TaskSheet({this.task});

  final Task? task;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final TextEditingController _title = TextEditingController();
  late DateTime _date;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.task;
    if (existing != null) {
      // 编辑：预填原内容，让用户看着改
      _title.text = existing.title;
      _date = existing.date;
    } else {
      // 新增：默认日期 = 录入日的次日（F3 第 2 条「今天录的明天做」）
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day + 1);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// 标题去空格后非空才允许保存（AC-10）
  bool get _canSave => _title.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    final text = _title.text.trim();
    if (text.isEmpty) return; // 双保险：按钮已禁用，这里再挡一次
    Navigator.of(context).pop(_NewTaskInput(text, _date));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 键盘弹出时把面板顶上去，否则输入框会被盖住
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? '编辑事项' : '新增事项',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B1F24),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: '要做什么？',
                filled: true,
                fillColor: const Color(0xFFF4F6F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  _dateLabel(_date),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1B1F24),
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: _pickDate, child: const Text('改期')),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                // 标题为空时按钮直接禁用 —— 这就是 AC-10 的「不可保存」
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============ 5. 长按菜单：编辑 / 删除（AC-12 / AC-13 / AC-15） ============ */

/// 长按菜单里的两个动作。
enum _TaskAction { edit, delete }

/// 长按整条框后从底部弹出的菜单。
///
/// 每一项用 `ListTile`：默认高度 56 dp、宽度撑满整屏，远超 AC-15 要求的
/// 44×44 dp，手指不会打偏。菜单本身不碰数据，只把一个 [_TaskAction] 交回首页。
class _TaskMenu extends StatelessWidget {
  const _TaskMenu({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 把被长按的那条事项标题显示出来，避免长按错了条目还浑然不知
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1F24),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
            title: const Text('编辑'),
            onTap: () => Navigator.of(context).pop(_TaskAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            title: const Text('删除'),
            onTap: () => Navigator.of(context).pop(_TaskAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
