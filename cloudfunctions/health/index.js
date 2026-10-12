// 云函数 health —— 对应公网路径 /api/health
// 通过 HTTP 网关访问时，返回的对象会被自动序列化成 JSON
exports.main = async (event, context) => {
  return {
    ok: true,
    service: 'today-todo',
    version: '0.1.0',
    serverTime: new Date().toISOString(),
  };
};
