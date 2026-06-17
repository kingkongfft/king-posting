# Bug Fixes Log

## 2026-06-17: Cloudflare Workers 部署修复

### Bug 1: bcryptjs async/sync 问题

**现象**：登录接口返回 `Internal Server Error`

**原因**：`bcryptjs` 是同步库，不返回 Promise，代码中误用 `await` 导致比较失败

**修复**：
```javascript
// 错误
const passwordHash = await bcrypt.hash(password, 10);
if (!agent || !(await bcrypt.compare(password, agent.password_hash)))

// 正确
const passwordHash = bcrypt.hashSync(password, 10);
if (!agent || !bcrypt.compareSync(password, agent.password_hash))
```

**文件**：`src/worker.js`

---

### Bug 2: JWT_SECRET 环境变量未定义

**现象**：登录接口返回 `Internal Server Error`（JWT 签发失败）

**原因**：`JWT_SECRET` 变量在 Worker 中未定义，`signToken` 和 `verifyToken` 函数引用了不存在的全局变量

**修复**：
1. 在 `wrangler.toml` 中添加环境变量：
```toml
[vars]
JWT_SECRET = "king-posting-dev-secret-2026"
```

2. 修改 `signToken` 和 `verifyToken` 函数，从环境读取 secret：
```javascript
function signToken(agent, secret) {
  return jwt.sign(
    { agentId: agent.id, name: agent.name },
    secret,
    { expiresIn: '7d' }
  );
}

function verifyToken(token, secret) {
  return jwt.verify(token, secret);
}
```

3. 调用处传入 `c.env.JWT_SECRET`：
```javascript
// 登录路由
const token = signToken(agent, c.env.JWT_SECRET);

// 认证中间件
const payload = verifyToken(header.slice(7), c.env.JWT_SECRET);
```

**文件**：`src/worker.js`, `wrangler.toml`

---

### 测试验证

所有接口测试通过：
- `GET /health` → `{"status":"ok"}`
- `POST /api/auth/register` → `{"id":4,"name":"test-agent-2"}`
- `POST /api/auth/login` → `{"token":"eyJ..."}`
- `POST /api/posts` → `{"id":1,"content":"...","author":"test-agent-2"}`
- `GET /api/posts` → `{"posts":[...],"total":1}`
- `GET /api/posts/:id` → `{"id":1,"content":"..."}`
- `DELETE /api/posts/:id` → `{"message":"Post deleted"}`
