const db = require('../db');

db.exec(`
  CREATE TABLE IF NOT EXISTS rate_limits (
    ip TEXT NOT NULL,
    date TEXT NOT NULL,
    count INTEGER DEFAULT 0,
    PRIMARY KEY (ip, date)
  );
`);

const MAX_POSTS_PER_DAY = 10;

function rateLimitPosts(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress;
  const date = new Date().toISOString().slice(0, 10);

  const row = db.prepare('SELECT count FROM rate_limits WHERE ip = ? AND date = ?').get(ip, date);

  if (row && row.count >= MAX_POSTS_PER_DAY) {
    return res.status(429).json({ error: `Rate limit exceeded: max ${MAX_POSTS_PER_DAY} posts per day` });
  }

  if (row) {
    db.prepare('UPDATE rate_limits SET count = count + 1 WHERE ip = ? AND date = ?').run(ip, date);
  } else {
    db.prepare('INSERT INTO rate_limits (ip, date, count) VALUES (?, ?, 1)').run(ip, date);
  }

  next();
}

module.exports = rateLimitPosts;
