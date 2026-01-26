import express from 'express';
import * as AdminMgmt from '../controllers/AdminManagementController.js';
import { verifyAdminToken, verifyAdminRole } from '../middleware/auth.js';

const router = express.Router();

// List admins (superadmin/admin)
router.get('/', verifyAdminToken, verifyAdminRole, AdminMgmt.listAdmins);
// Create admin (superadmin only) - middleware will check roles
router.post('/', verifyAdminToken, verifyAdminRole, AdminMgmt.createAdmin);

// List users under admin
router.get('/:adminId/users', verifyAdminToken, verifyAdminRole, AdminMgmt.listUsersForAdmin);
// Create user under admin
router.post('/:adminId/users', verifyAdminToken, verifyAdminRole, AdminMgmt.createUserUnderAdmin);

// Superadmin-only: update admin status (ban/approve)
router.put('/:adminId/status', verifyAdminToken, AdminMgmt.updateAdminStatus);

// Superadmin-only: delete admin
router.delete('/:adminId', verifyAdminToken, AdminMgmt.deleteAdmin);

// ============================================
// STORE APPROVAL MANAGEMENT
// ============================================

// Get pending stores for approval
router.get('/stores/pending', verifyAdminToken, AdminMgmt.getPendingStores);

// Get approved stores
router.get('/stores/approved', verifyAdminToken, AdminMgmt.getApprovedStores);

// 🔥 NEW: Get ALL stores with REAL status from database (critical fix)
router.get('/stores/all', verifyAdminToken, AdminMgmt.getAllStoresAdmin);

// Approve a store (change status from pending to approved)
router.post('/stores/:storeId/approve', verifyAdminToken, AdminMgmt.approveStore);

// Reject a store (change status to rejected)
router.post('/stores/:storeId/reject', verifyAdminToken, AdminMgmt.rejectStore);

// Ban a store (change status to banned)
router.post('/stores/:storeId/ban', verifyAdminToken, AdminMgmt.banStore);

// ============================================
// DELIVERY DRIVER APPROVAL MANAGEMENT
// ============================================

// Get pending drivers for approval
router.get('/drivers/pending', verifyAdminToken, AdminMgmt.getPendingDrivers);

// Get approved drivers
router.get('/drivers/approved', verifyAdminToken, AdminMgmt.getApprovedDrivers);

// Get active drivers (approved and is_working = 1)
router.get('/drivers/active', verifyAdminToken, AdminMgmt.getActiveDrivers);

// Approve a driver (change status from pending to approved)
router.post('/drivers/:driverId/approve', verifyAdminToken, AdminMgmt.approveDriver);

// Reject a driver (change status to rejected)
router.post('/drivers/:driverId/reject', verifyAdminToken, AdminMgmt.rejectDriver);

// Ban a driver (change status to banned)
router.post('/drivers/:driverId/ban', verifyAdminToken, AdminMgmt.banDriver);

export default router;
