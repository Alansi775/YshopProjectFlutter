import express from 'express';
import { staffLogin } from '../controllers/StaffAuthController.js';

const router = express.Router();

// POST /api/v1/staff/login
router.post('/login', staffLogin);

export default router;
