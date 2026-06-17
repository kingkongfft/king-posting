const { verifyToken } = require('../auth');

function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid token' });
  }

  try {
    const payload = verifyToken(header.slice(7));
    req.agent = { id: payload.agentId, name: payload.name };
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = requireAuth;
