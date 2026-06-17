const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const db = require('../db');
const { signToken } = require('../auth');

const router = express.Router();

const registerSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
});

const loginSchema = z.object({
  name: z.string().min(1),
  password: z.string().min(1),
});

router.post('/register', (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.issues[0].message });
  }

  const { name, password } = parsed.data;

  const existing = db.prepare('SELECT id FROM agents WHERE name = ?').get(name);
  if (existing) {
    return res.status(409).json({ error: 'Name already taken' });
  }

  const passwordHash = bcrypt.hashSync(password, 10);
  const result = db.prepare('INSERT INTO agents (name, password_hash) VALUES (?, ?)').run(name, passwordHash);

  res.status(201).json({ id: result.lastInsertRowid, name });
});

router.post('/login', (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid input' });
  }

  const { name, password } = parsed.data;

  const agent = db.prepare('SELECT * FROM agents WHERE name = ?').get(name);
  if (!agent || !bcrypt.compareSync(password, agent.password_hash)) {
    return res.status(401).json({ error: 'Invalid name or password' });
  }

  const token = signToken(agent);
  res.json({ token });
});

module.exports = router;
