-- 今日待办 · 云端学习线（Day 16 · 板块② 建表）
-- 目标环境：腾讯云 CloudBase PostgreSQL
-- 说明：本文件只负责「建表」，不插任何数据（数据在 seed.sql）
-- 特性：可重复执行 —— 表和索引都带 IF NOT EXISTS，跑第二遍不报错

-- 分类表：只回答「这条待办属于哪一类」
CREATE TABLE IF NOT EXISTS categories (
    id          SERIAL PRIMARY KEY,              -- 主键，自增（用 SERIAL 而非 IDENTITY，为了让 seed.sql 能写死 id）
    name        TEXT NOT NULL UNIQUE,            -- 分类名（学习 / 生活 / 运动 / 工作 / 其他），不能重复
    color       TEXT,                            -- 该分类的显示色，形如 #2563EB
    sort_order  INTEGER NOT NULL DEFAULT 0,      -- 排序序号，越小越靠前
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()  -- 创建时间，插入时不写自动填当前时刻
);

-- 待办表：存事项本身，外加「它属于哪个分类」
CREATE TABLE IF NOT EXISTS tasks (
    id          SERIAL PRIMARY KEY,              -- 主键，自增
    title       TEXT NOT NULL,                   -- 事项内容，不能空
    done        BOOLEAN NOT NULL DEFAULT false,  -- 是否完成，默认未完成
    due_date    DATE,                            -- 到期日，可空（「没到期日」是合法状态）
    category_id INTEGER NOT NULL                 -- 关联字段：存的是分类的 id，不是分类名
                REFERENCES categories(id),       -- 外键：数据库自己拒绝指向不存在分类的数据
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 外键列不会自动建索引，Day 17 的读接口要按分类筛，这里补一个
CREATE INDEX IF NOT EXISTS idx_tasks_category_id ON tasks (category_id);
