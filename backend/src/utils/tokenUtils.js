import jwt from 'jsonwebtoken';
import crypto from 'crypto';

// Use ADMIN_JWT_SECRET first for consistency across all token generation
const JWT_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'change_this_secret';
const JWT_EXPIRES_IN = '7d';

export const generateJWT = (userId, email, role = 'user') => {
  return jwt.sign(
    {
      id: userId,
      email,
      role,
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
};

export const verifyJWT = (token) => {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
};

export const generateVerificationToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

export const generateTokenExpiry = (hours = 24) => {
  const now = new Date();
  now.setHours(now.getHours() + hours);
  return now;
};
