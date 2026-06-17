const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const JWT_EXPIRES = '7d';

function signToken(agent) {
  return jwt.sign(
    { agentId: agent.id, name: agent.name },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES }
  );
}

function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

module.exports = { signToken, verifyToken };
