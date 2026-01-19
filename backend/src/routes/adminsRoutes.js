import express from 'express';
import * as AdminMgmt from '../controllers/AdminManagementController.js';
import { verifyFirebaseToken, verifyAdminRole } from '../middleware/auth.js';

const router = express.Router();

// List admins (superadmin/admin)
router.get('/', verifyFirebaseToken, verifyAdminRole, AdminMgmt.listAdmins);
// Create admin (superadmin only) - middleware will check roles
router.post('/', verifyFirebaseToken, verifyAdminRole, AdminMgmt.createAdmin);

// List users under admin
router.get('/:adminId/users', verifyFirebaseToken, verifyAdminRole, AdminMgmt.listUsersForAdmin);
// Create user under admin
router.post('/:adminId/users', verifyFirebaseToken, verifyAdminRole, AdminMgmt.createUserUnderAdmin);

// Superadmin-only: update admin status (ban/approve)
router.put('/:adminId/status', verifyFirebaseToken, verifyAdminRole, AdminMgmt.updateAdminStatus);

// Superadmin-only: delete admin
router.delete('/:adminId', verifyFirebaseToken, verifyAdminRole, AdminMgmt.deleteAdmin);

export default router;
