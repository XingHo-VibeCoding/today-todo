/* 今日待办 —— 页面骨架（Day 7 · 板块② 第 1 步）
 *
 * 本步只做三件事：
 *   1. 页面结构  → index.html
 *   2. 样式      → styles.css
 *   3. 把清单渲染出来 → 本文件
 *
 * 数据源：IndexedDB（浏览器内置的本地数据库）。
 * 首次打开时写入 4 条示例数据，之后所有改动都写进数据库，
 * 刷新页面、关掉重开都不会丢。
 *
 * 交互现状：点整条框 = 标记完成，再点一次 = 撤销（已接上）；
 * 编辑 / 删除两个按钮还没接，点了暂时没有反应。
 */

/* ============ 1. 工具函数 ============ */

const DAY_MS = 24 * 60 * 60 * 1000;

/** 今天零点，往后推 n 天 */
function dayOffset(n) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + n);
  return d;
}

/** 日期显示成「今天 / 明天 / 昨天 / 9月25日」（入参是时间戳） */
function formatDate(ts) {
  const date = new Date(ts);
  const diff = Math.round((date - dayOffset(0)) / DAY_MS);
  if (diff === 0) return '今天';
  if (diff === 1) return '明天';
  if (diff === -1) return '昨天';
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

/** 转义标题里的特殊字符，避免 < > 之类的字符破坏页面结构 */
function escapeHTML(str) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  return String(str).replace(/[&<>"']/g, ch => map[ch]);
}

/* ============ 2. 数据层：IndexedDB ============ */

const DB_NAME = 'today-todo';   // 数据库名
const DB_VERSION = 1;           // 版本号，将来改表结构时 +1
const STORE = 'tasks';          // 「表」名

/* 首次打开时写入的 4 条示例数据，覆盖四种典型情况，方便一眼看出样式对不对 */
const SEED = [
  { title: '水卡充值',   date: dayOffset(-1).getTime(), done: false, repeat: null }, // 逾期未完成
  { title: '交实验报告', date: dayOffset(0).getTime(),  done: false, repeat: null }, // 今天到期
  { title: '洗衣服',     date: dayOffset(2).getTime(),  done: false, repeat: null }, // 后天
  { title: '倒垃圾',     date: dayOffset(-1).getTime(), done: true,  repeat: null }, // 已完成
];

/** 内存里的当前数据，由 loadFromDB() 从数据库填进来；渲染只读它 */
let tasks = [];
let db = null;

/** 打开数据库；第一次打开时会自动建表并写入示例数据 */
function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);

    // 只有数据库第一次创建（或版本号变大）时才会走到这里
    req.onupgradeneeded = () => {
      const store = req.result.createObjectStore(STORE, { keyPath: 'id', autoIncrement: true });
      SEED.forEach(item => store.add(item));
    };

    req.onsuccess = () => resolve(req.result);
    req.onerror   = () => reject(req.error);
  });
}

/**
 * 开一次数据库事务并等它结束。作用是把「回调式」的 IndexedDB 包成 Promise，
 * 这样外面就能用 await 写，不用层层嵌套回调。
 * @param {'readonly'|'readwrite'} mode 读还是写
 * @param {(store) => IDBRequest} fn    这次要做的操作
 */
function withStore(mode, fn) {
  return new Promise((resolve, reject) => {
    const t = db.transaction(STORE, mode);
    const req = fn(t.objectStore(STORE));
    let value;
    req.onsuccess = () => { value = req.result; };
    t.oncomplete  = () => resolve(value);   // 事务整体提交成功才算数
    t.onerror     = () => reject(t.error);
  });
}

const dbGetAll = ()   => withStore('readonly',  s => s.getAll());
const dbPut    = task => withStore('readwrite', s => s.put(task));
const dbAdd    = task => withStore('readwrite', s => s.add(task));
const dbDelete = id   => withStore('readwrite', s => s.delete(id));

/** 从数据库把全部事项读进内存 */
async function loadFromDB() {
  tasks = await dbGetAll();
}

/* ============ 3. 渲染 ============ */

const el = {
  todayText:    document.getElementById('today-text'),
  pendingList:  document.getElementById('list-pending'),
  doneList:     document.getElementById('list-done'),
  pendingCount: document.getElementById('count-pending'),
  doneCount:    document.getElementById('count-done'),
  doneSection:  document.getElementById('section-done'),

  sheet:        document.getElementById('sheet'),
  sheetTitle:   document.getElementById('sheet-title'),
  inputTitle:   document.getElementById('input-title'),
  inputDate:    document.getElementById('input-date'),
  saveBtn:      document.getElementById('btn-save'),

  confirm:      document.getElementById('confirm'),
  confirmText:  document.getElementById('confirm-text'),
};

const ICON_EDIT = `<svg width="19" height="19" viewBox="0 0 24 24" fill="none"
  stroke="currentColor" stroke-width="1.8" stroke-linecap="round"
  stroke-linejoin="round" aria-hidden="true">
  <path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/>
</svg>`;

const ICON_DELETE = `<svg width="19" height="19" viewBox="0 0 24 24" fill="none"
  stroke="currentColor" stroke-width="1.8" stroke-linecap="round"
  stroke-linejoin="round" aria-hidden="true">
  <path d="M3 6h18"/><path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"/>
  <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
</svg>`;

/** 一条事项的 HTML */
function itemHTML(task) {
  const overdue = !task.done && task.date < dayOffset(0).getTime();
  return `
    <li class="item${task.done ? ' item--done' : ''}" data-id="${task.id}">
      <div class="item__body">
        <p class="item__title">${escapeHTML(task.title)}</p>
        <p class="item__meta${overdue ? ' item__meta--overdue' : ''}">${formatDate(task.date)}</p>
      </div>
      <button class="item__act" type="button" data-act="edit"
              aria-label="编辑" title="编辑">${ICON_EDIT}</button>
      <button class="item__act item__act--del" type="button" data-act="delete"
              aria-label="删除" title="删除">${ICON_DELETE}</button>
    </li>`;
}

function render() {
  // 未完成：按日期升序 —— 越早到期的越靠前，逾期未完成的自然排最上面（AC-5）
  const pending = tasks.filter(t => !t.done).sort((a, b) => a.date - b.date);
  // 已完成：永远排在未完成之后（AC-3）
  const done = tasks.filter(t => t.done).sort((a, b) => b.date - a.date);

  el.pendingList.innerHTML = pending.length
    ? pending.map(itemHTML).join('')
    : '<li class="list__empty">今天没有待办，点下面新增一条</li>';
  el.doneList.innerHTML = done.map(itemHTML).join('');

  el.pendingCount.textContent = pending.length;
  el.doneCount.textContent = done.length;
  el.doneSection.hidden = done.length === 0;
}

/* ============ 4. 交互 ============ */

/** 点一下框：未完成 → 完成；已完成 → 撤销（并写回数据库） */
async function toggleDone(id) {
  const task = tasks.find(t => t.id === id);
  if (!task) return;
  task.done = !task.done;
  render();                 // 先更新界面：点下去立刻有反应
  await dbPut(task);        // 再写进数据库：刷新后状态还在
}

/* pressAt 用来区分「滑动」和「单击」：记下手指按下的位置和时间 */
let pressAt = null;

function onPointerDown(e) {
  if (!e.isPrimary) return;                        // 多指触摸只认第一根手指
  pressAt = { x: e.clientX, y: e.clientY, t: Date.now() };
}

function onListClick(e) {
  const item = e.target.closest('.item');
  if (!item) return;

  // 点的是编辑 / 删除按钮 → 走各自分支，不当作「完成」
  const act = e.target.closest('[data-act]');
  if (act) {
    const id = Number(item.dataset.id);
    if (act.dataset.act === 'edit') openForm(id);
    if (act.dataset.act === 'delete') askDelete(id);
    return;
  }

  if (pressAt) {
    const moved = Math.hypot(e.clientX - pressAt.x, e.clientY - pressAt.y);
    const held = Date.now() - pressAt.t;
    pressAt = null;
    // 挪动超过 10px → 滑动；按住超过 500ms → 长按。两种情况都不算单击
    if (moved > 10 || held > 500) return;
  }

  toggleDone(Number(item.dataset.id));
}

[el.pendingList, el.doneList].forEach(list => {
  list.addEventListener('pointerdown', onPointerDown);
  list.addEventListener('click', onListClick);
});

/* ============ 5. 启动 ============ */

(async function init() {
  // 顶部日期不依赖数据库，先显示出来
  const now = new Date();
  const week = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][now.getDay()];
  el.todayText.textContent = `${now.getMonth() + 1}月${now.getDate()}日 ${week}`;

  try {
    db = await openDB();
    await loadFromDB();      // 数据从数据库读出来
    render();
  } catch (err) {
    // 数据库打不开（隐私模式、被禁用、配额满等）→ 明确告知，别白屏
    el.pendingList.innerHTML =
      `<li class="list__empty">数据打不开：${escapeHTML(err.message)}</li>`;
  }
})();

/* ============ 6. 新增 / 编辑 / 删除 ============ */

let editingId = null;        // 正在编辑哪一条；null 表示「新增」
let pendingDeleteId = null;  // 等着确认删除哪一条

/** 时间戳 → 日期输入框要的「2026-09-23」 */
function toInputValue(ts) {
  const d = new Date(ts);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** 「2026-09-23」→ 时间戳（当地零点） */
function fromInputValue(str) {
  const [y, m, d] = str.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

/** 打开表单：给 id 是编辑，不给是新增 */
function openForm(id) {
  editingId = id || null;
  el.sheetTitle.textContent = editingId ? '编辑事项' : '新增事项';

  if (editingId) {
    const task = tasks.find(t => t.id === editingId);
    if (!task) return;
    el.inputTitle.value = task.title;
    el.inputDate.value = toInputValue(task.date);
  } else {
    el.inputTitle.value = '';
    el.inputDate.value = toInputValue(dayOffset(1).getTime());   // 默认明天（AC-11）
  }

  el.saveBtn.disabled = !el.inputTitle.value.trim();             // 空标题不能保存（AC-10）
  el.sheet.hidden = false;
  el.inputTitle.focus();
}

function closeSheet() {
  el.sheet.hidden = true;
  editingId = null;
}

/** 保存：新增就往库里加一条；编辑就改原来那条（AC-13：不产生新条目） */
async function saveTask(event) {
  event.preventDefault();

  const title = el.inputTitle.value.trim();
  if (!title) return;                                   // 兜底：空标题一律不保存

  const date = el.inputDate.value
    ? fromInputValue(el.inputDate.value)
    : dayOffset(1).getTime();                           // 日期被清空 → 仍按「明天」

  if (editingId) {
    const task = tasks.find(t => t.id === editingId);
    task.title = title;
    task.date = date;
    await dbPut(task);
  } else {
    const task = { title, date, done: false, repeat: null };
    task.id = await dbAdd(task);
    tasks.push(task);
  }

  closeSheet();
  render();
}

/** 删除第一步：先问一句（AC-15：不做无提示的直接删除） */
function askDelete(id) {
  const task = tasks.find(t => t.id === id);
  if (!task) return;
  pendingDeleteId = id;
  el.confirmText.textContent = task.title;
  el.confirm.hidden = false;
}

function closeConfirm() {
  el.confirm.hidden = true;
  pendingDeleteId = null;
}

/** 删除第二步：确认后才真删 */
async function doDelete() {
  const id = pendingDeleteId;
  closeConfirm();
  if (id === null) return;

  tasks = tasks.filter(t => t.id !== id);
  render();
  await dbDelete(id);
}

/* ---- 把面板和按钮接上 ---- */

document.getElementById('task-form').addEventListener('submit', saveTask);
document.getElementById('btn-add').addEventListener('click', () => openForm(null));
document.getElementById('btn-cancel').addEventListener('click', closeSheet);
document.getElementById('sheet-mask').addEventListener('click', closeSheet);

document.getElementById('btn-del-cancel').addEventListener('click', closeConfirm);
document.getElementById('confirm-mask').addEventListener('click', closeConfirm);
document.getElementById('btn-del-ok').addEventListener('click', doDelete);

// 一边打字一边判断能不能保存
el.inputTitle.addEventListener('input', () => {
  el.saveBtn.disabled = !el.inputTitle.value.trim();
});
