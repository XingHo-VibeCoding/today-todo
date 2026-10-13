-- 今日待办 · 云端学习线（Day 16 · 板块③ 种子脚本）
-- 作用：往两张表里铺「练习用示例数据」—— 分类 5 条 + 待办 8 条
-- 特性：可重复执行 —— 写死 id + ON CONFLICT DO NOTHING；跑第二遍不报错，也不会插出重复行

-- 分类：5 条（色值只是示例，没跟产品配色对齐 —— 甲 = 练习作品）
INSERT INTO categories (id, name, color, sort_order) VALUES
    (1, '学习', '#2563EB', 1),
    (2, '生活', '#16A34A', 2),
    (3, '运动', '#C2410C', 3),
    (4, '工作', '#7C3AED', 4),
    (5, '其他', '#68707E', 5)
ON CONFLICT DO NOTHING;

-- 待办：8 条，category_id 指向上面那 5 个分类的 id
-- 日期相对「今天」算，所以隔几天再跑，日期依然合理
INSERT INTO tasks (id, title, done, due_date, category_id) VALUES
    (1, '交实验报告',        false, CURRENT_DATE,     1),
    (2, '背六级单词 50 个',   true,  CURRENT_DATE,     1),
    (3, '水卡充值',          false, CURRENT_DATE - 1, 2),
    (4, '洗衣服',            false, CURRENT_DATE + 2, 2),
    (5, '慢跑 3 公里',        true,  CURRENT_DATE - 2, 3),
    (6, '开小组会',          false, CURRENT_DATE + 1, 4),
    (7, '整理下周计划',       false, CURRENT_DATE + 3, 4),
    (8, '倒垃圾',            true,  CURRENT_DATE - 1, 5)
ON CONFLICT DO NOTHING;

-- 修正自增序列：上面是写死 id 插的，序列没跟着往前跑。
-- 不修的话，以后用「不带 id」的方式插数据会从 1 开始，直接撞主键报错。
SELECT setval(pg_get_serial_sequence('categories', 'id'), (SELECT MAX(id) FROM categories));
SELECT setval(pg_get_serial_sequence('tasks',      'id'), (SELECT MAX(id) FROM tasks));
