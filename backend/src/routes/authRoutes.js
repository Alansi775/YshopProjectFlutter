import { Router } from 'express';
import AuthController from '../controllers/AuthController.js';
import { verifyFirebaseToken } from '../middleware/auth.js';

const router = Router();

//  NEW: Logout endpoint for cleanup on backend if needed
router.post('/logout', verifyFirebaseToken, (req, res) => {
  // Token-based auth means logout happens client-side (Firebase)
  // Backend just confirms the logout
  res.json({
    success: true,
    message: 'Logout successful - clear client cache',
  });
});

// Change password for current authenticated user/admin
router.put('/me/password', verifyFirebaseToken, AuthController.changeMyPassword);

export default router;
