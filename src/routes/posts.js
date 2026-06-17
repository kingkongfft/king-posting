const express = require('express');
const { z } = require('zod');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const rateLimitPosts = require('../middleware/rateLimit');

const router = express.Router();

const createPostSchema = z.object({
  content: z.string().min(1, 'Content is required').max(2000, 'Content must be at most 2000 characters'),
});

router.get('/', (req, res) => {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  const offset = (page - 1) * limit;

  const posts = db.prepare(`
    SELECT p.id, p.content, p.created_at, a.name as author
    FROM posts p
    JOIN agents a ON p.agent_id = a.id
    WHERE p.deleted_at IS NULL
    ORDER BY p.created_at DESC
    LIMIT ? OFFSET ?
  `).all(limit, offset);

  const { total } = db.prepare('SELECT COUNT(*) as total FROM posts WHERE deleted_at IS NULL').get();

  res.json({ posts, page, limit, total });
});

router.get('/:id', (req, res) => {
  const post = db.prepare(`
    SELECT p.id, p.content, p.created_at, a.name as author
    FROM posts p
    JOIN agents a ON p.agent_id = a.id
    WHERE p.id = ? AND p.deleted_at IS NULL
  `).get(req.params.id);

  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }

  res.json(post);
});

router.post('/', requireAuth, rateLimitPosts, (req, res) => {
  const parsed = createPostSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.issues[0].message });
  }

  const { content } = parsed.data;
  const result = db.prepare('INSERT INTO posts (agent_id, content) VALUES (?, ?)').run(req.agent.id, content);

  const post = db.prepare('SELECT id, content, created_at FROM posts WHERE id = ?').get(result.lastInsertRowid);
  res.status(201).json({ ...post, author: req.agent.name });
});

router.delete('/:id', requireAuth, (req, res) => {
  const post = db.prepare('SELECT * FROM posts WHERE id = ? AND deleted_at IS NULL').get(req.params.id);

  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }

  if (post.agent_id !== req.agent.id) {
    return res.status(403).json({ error: 'You can only delete your own posts' });
  }

  db.prepare('UPDATE posts SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?').run(req.params.id);
  res.json({ message: 'Post deleted' });
});

module.exports = router;
