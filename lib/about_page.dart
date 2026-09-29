import 'package:flutter/material.dart';

import 'design.dart';

/// 关于页（Day 13）—— 本产品**第一个二级页面**，从首页页头标题区点进来。
///
/// 为什么要单独一个文件：`main.dart` 已经 960 行，再塞一个页面会到 1050+；
/// 更要紧的是二级页和首页是两件不同的事，混在一个文件里以后找起来费劲。
///
/// **它为什么不算违反 PRD 第四节**：差异点写的是「待办是页面的唯一主角」，
/// 防的是**首屏被功能入口和视图切换淹没**。这个页面从已有的标题区下钻，
/// 首页首屏元素一个没加，所以两边不冲突。
///
/// **它不读库、不写库**，内容全是写死的静态文字——所以加载 / 空 / 错误这几
/// 种数据状态在这里不存在，四种状态仍然只发生在首页的事项列表上。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 命名路由的名字。写在这里而不是 `main.dart` 里，免得字符串散成两处。
  static const String routeName = '/about';

  /// 版本号写死，来源是 `pubspec.yaml` 的 `version: 1.0.0+1`。
  /// 不引 `package_info_plus`——为了显示一个字符串加一个原生插件不划算。
  /// 改了 pubspec 的版本号，记得回来改这里。
  static const String _version = 'v1.0.0';

  /// 差异点三条，原文抄自 `PRD.md` 第四节的核心价值与差异化表。
  static const List<String> _diffPoints = [
    '信息层级 > 功能数量：待办是页面的唯一主角',
    '提醒 = 每天固定 1–2 次清点今日，而非临期反复催办',
    '无付费引导、无干扰性弹窗',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 返回箭头不用自己写：pushNamed 进来的，AppBar 按 Navigator.canPop 自动挂上
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: Colors.white,
        // M3 的 AppBar 默认会被主题色染一层、滚动时再加深，两级都关掉才是纯白
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        children: [
          const Text(
            '今日待办',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            _version,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          const Text(
            '面向大学生的碎片事务提醒工具',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // 差异点。三条拼成一个 Text 而不是三个：换行和行距由 height 管，
          // 每行前面加「·」，比三个 Padding 套 Text 少一半代码。
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '差异点',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _diffPoints.map((p) => '· $p').join('\n'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.9,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '开发者 Charlie-xylz',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
