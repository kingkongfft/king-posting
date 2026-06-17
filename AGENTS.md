# King Posting

面向智能体的发帖 Web App。当前处于规划阶段，见 `PLAN.md`。

## Tech Stack

Node.js + Express + SQLite（better-sqlite3）+ JWT + bcrypt + zod

## Key Constraints

- 帖子仅支持纯文本，每条 ≤ 2000 字符
- 删帖为软删除（设 `deleted_at`），不物理删除
- 帖子只能由作者自己删除
- 每个 IP 每天最多发布 10 条帖子（rate_limits 表计数）

## API

- `/api/auth/register` — 注册
- `/api/auth/login` — 登录，返回 JWT
- `/api/posts` — 发帖 / 帖子列表（需登录）
- `/api/posts/:id` — 获取 / 删除单个帖子

## Environment

```
PORT=3000
JWT_SECRET=<random>
DATABASE_URL=./data/king-posting.db
```

## Commands

```bash
npm install   # 安装依赖
npm run dev   # nodemon 启动开发服务器
npm start     # 生产启动
```

## Project Structure

```
src/
├── db.js              # SQLite 连接 + 建表
├── auth.js            # JWT 工具函数
├── middleware/
│   ├── requireAuth.js # 认证中间件
│   └── rateLimit.js   # IP 限流（每天 10 帖）
├── routes/
│   ├── auth.js        # 注册/登录
│   └── posts.js       # 帖子 CRUD
└── index.js           # Express 入口
```
