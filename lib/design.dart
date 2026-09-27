import 'package:flutter/material.dart';

import 'db.dart';

/// 设计常量与组件样式约束。
///
/// 为什么单独一个文件：`main.dart` 已经 871 行；更重要的是这些色值和「一条事项
/// 长什么样」的规则以后别的页面也要用，放在这里 `import` 一下拿到的是同一套，
/// 不会各抄一份、各抄错一处。

/// 卡片状态配色用到的色值（Day 9 落地的灰阶三级制 + 两档染色）。
///
/// 每个色值后面标的对比度都是**实测值**（WCAG 相对亮度公式，算器见
/// `D:\dev\day9_contrast.py`）——换值时必须重算，尤其是放在染色底上的那几个。
abstract final class AppColors {
  /// L1 主文字。对白卡 16.56:1、对浅红底 13.11:1、对浅绿底 13.77:1
  static const textPrimary = Color(0xFF1B1F24);

  /// L2 次文字。对白卡 6.00:1、对浅绿底 4.99:1
  static const textSecondary = Color(0xFF5A6472);

  /// L3 提示 / 日期。对白卡 4.99:1。
  /// **不能直接放到染色底上**——那里只有 3.96～4.16:1，低于 AA 的 4.5:1。
  static const textHint = Color(0xFF68707E);

  /// 逾期日期。对浅红底 5.12:1
  static const overdueText = Color(0xFFB91C1C);

  /// 卡片白底
  static const card = Colors.white;

  /// 白卡描边。**有意不追 3:1**：浅色主题下卡片边框取任何浅灰都到不了，
  /// 要达标就得画深灰粗框，那是更差的设计；W3C 1.4.11 对装饰性边界是豁免的。
  static const cardBorder = Color(0xFFDCE2E9);

  /// 卡片状态底色：半透明 10%，叠在页面底 `#F4F6F8` 上。
  /// 只用两档——未来待办维持白卡，全染等于没有重点，红色会被稀释。
  static const tintOverdue = Color(0x1ADC2626); // 实际渲染 #F1E1E3
  static const tintToday = Color(0x1A16A34A); // 实际渲染 #DDEEE7
}

/// 一条事项卡片该长什么样——**「卡片状态配色」这条规则的唯一出口**。
///
/// 判断逻辑散在组件里的话，以后加 F4 周期状态、或把卡片复用到别的页面，都要
/// 重新抄一遍判断，抄漏一处就出错。收进这里，调用方只有一个入口 [of]。
class TaskCardStyle {
  const TaskCardStyle({
    required this.background,
    required this.border,
    required this.titleColor,
    required this.dateColor,
    required this.dateBold,
  });

  final Color background;

  /// 只有白卡给描边，染色卡为 null（见 [of] 里的说明）
  final Border? border;

  final Color titleColor;
  final Color dateColor;

  /// 逾期日期加粗。底色已经浅，字重是第二重强调
  final bool dateBold;

  /// 按事项当前状态给出配色。判定口径：
  ///   - 未完成 + 日期在今天之前 → 逾期：红底、去描边、深红加粗日期
  ///   - 未完成 + 日期正是今天   → 今天：绿底、去描边
  ///   - 其余（已完成 / 未来）   → 白卡 + 描边
  /// 已完成走最后一档，灰字与删除线由组件自己加，不在这里管。
  factory TaskCardStyle.of(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 归一化到零点再比：库里存的是毫秒时间戳，可能带时分秒
    final day = DateTime(task.date.year, task.date.month, task.date.day);
    final diff = day.difference(today).inDays;

    final overdue = !task.done && diff < 0;
    final dueToday = !task.done && diff == 0;

    if (overdue) {
      return const TaskCardStyle(
        background: AppColors.tintOverdue,
        border: null,
        titleColor: AppColors.textPrimary,
        dateColor: AppColors.overdueText, // 对浅红底 5.12:1
        dateBold: true,
      );
    }
    if (dueToday) {
      return const TaskCardStyle(
        background: AppColors.tintToday,
        border: null,
        titleColor: AppColors.textPrimary,
        dateColor: AppColors.textSecondary, // 对浅绿底 4.99:1
        dateBold: false,
      );
    }
    return TaskCardStyle(
      background: AppColors.card,
      // 白卡必须靠描边才有边界（白 vs 页面底只有 1.08:1）；
      // 染色卡不描边——色块自己成立，再叠一条灰线反而显脏
      border: Border.all(color: AppColors.cardBorder),
      titleColor: task.done ? AppColors.textHint : AppColors.textPrimary,
      dateColor: AppColors.textHint, // 对白卡 4.99:1
      dateBold: false,
    );
  }
}
