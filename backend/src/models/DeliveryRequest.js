import pool from '../config/database.js';
import logger from '../config/logger.js';

export class DeliveryRequest {
  static async createOrUpdate(data) {
    try {
      const { uid, email, name, phone, national_id, address } = data;
      const connection = await pool.getConnection();
      const [res] = await connection.execute(
        `INSERT INTO delivery_requests (uid,email,name,phone,national_id,address,status,created_at,updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 'Pending', NOW(), NOW())
         ON DUPLICATE KEY UPDATE email=VALUES(email), name=VALUES(name), phone=VALUES(phone), national_id=VALUES(national_id), address=VALUES(address), status='Pending', updated_at=NOW()`,
        [uid, email || null, name || null, phone || null, national_id || null, address || null]
      );
      connection.release();
      return res;
    } catch (error) {
      logger.error('Error in DeliveryRequest.createOrUpdate', error);
      throw error;
    }
  }

  static async findByUid(uid) {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute('SELECT * FROM delivery_requests WHERE uid = ?', [uid]);
      connection.release();
      return rows[0];
    } catch (error) {
      logger.error('Error in DeliveryRequest.findByUid', error);
      throw error;
    }
  }

  static async findById(id) {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute('SELECT * FROM delivery_requests WHERE id = ?', [id]);
      connection.release();
      return rows[0];
    } catch (error) {
      logger.error('Error in DeliveryRequest.findById', error);
      throw error;
    }
  }

  static async listPending() {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute("SELECT * FROM delivery_requests WHERE status='Pending' ORDER BY created_at DESC");
      connection.release();
      return rows;
    } catch (error) {
      logger.error('Error in DeliveryRequest.listPending', error);
      throw error;
    }
  }

  static async listActive() {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute("SELECT * FROM delivery_requests WHERE status='Approved' AND is_working = 1 ORDER BY updated_at DESC");
      connection.release();
      return rows;
    } catch (error) {
      logger.error('Error in DeliveryRequest.listActive', error);
      throw error;
    }
  }

  static async listApproved() {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute("SELECT * FROM delivery_requests WHERE status='Approved' ORDER BY updated_at DESC");
      connection.release();
      return rows;
    } catch (error) {
      logger.error('Error in DeliveryRequest.listApproved', error);
      throw error;
    }
  }

  static async updateStatus(id, status) {
    try {
      const connection = await pool.getConnection();
      const [res] = await connection.execute('UPDATE delivery_requests SET status=?, updated_at=NOW() WHERE id=?', [status, id]);
      connection.release();
      return res;
    } catch (error) {
      logger.error('Error in DeliveryRequest.updateStatus', error);
      throw error;
    }
  }

  static async updateIsWorkingByUid(uid, isWorking) {
    try {
      const connection = await pool.getConnection();
      const [res] = await connection.execute('UPDATE delivery_requests SET is_working = ?, updated_at = NOW() WHERE uid = ?', [isWorking ? 1 : 0, uid]);
      connection.release();
      return res;
    } catch (error) {
      logger.error('Error in DeliveryRequest.updateIsWorkingByUid', error);
      throw error;
    }
  }

  static async updateLocationByUid(uid, latitude, longitude) {
    try {
      const connection = await pool.getConnection();
      const [res] = await connection.execute(
        'UPDATE delivery_requests SET latitude = ?, longitude = ?, updated_at = NOW() WHERE uid = ?',
        [latitude, longitude, uid]
      );
      connection.release();
      return res;
    } catch (error) {
      logger.error('Error in DeliveryRequest.updateLocationByUid', error);
      throw error;
    }
  }

  static async deleteById(id) {
    try {
      const connection = await pool.getConnection();
      const [res] = await connection.execute('DELETE FROM delivery_requests WHERE id = ?', [id]);
      connection.release();
      return res;
    } catch (error) {
      logger.error('Error in DeliveryRequest.deleteById', error);
      throw error;
    }
  }



  // ═══════════════════════════════════════════════════════════════════════════════
// 🎁 NEW: Smart Driver Assignment Functions
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Find the closest available driver to a store location
 * @param {number} storeLat - Store latitude
 * @param {number} storeLng - Store longitude  
 * @param {string[]} excludeDriverIds - Driver IDs to exclude (already skipped)
 * @returns {object|null} - Closest driver or null
 */
static async findClosestAvailableDriver(storeLat, storeLng, excludeDriverIds = []) {
  const connection = await pool.getConnection();
  try {
    // Build exclude clause
    let excludeClause = '';
    const params = [storeLat, storeLng, storeLat];
    
    if (excludeDriverIds && excludeDriverIds.length > 0) {
      const placeholders = excludeDriverIds.map(() => '?').join(',');
      excludeClause = `AND uid NOT IN (${placeholders})`;
      params.push(...excludeDriverIds);
    }

    const sql = `
      SELECT 
        id, uid, name, email, phone, latitude, longitude,
        (6371000 * ACOS(
          COS(RADIANS(?)) * COS(RADIANS(latitude)) * COS(RADIANS(longitude) - RADIANS(?))
          + SIN(RADIANS(?)) * SIN(RADIANS(latitude))
        )) AS distance
      FROM delivery_requests
      WHERE status = 'Approved'
        AND is_working = 1
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
        ${excludeClause}
      ORDER BY distance ASC
      LIMIT 1`;

    const [rows] = await connection.execute(sql, params);
    connection.release();
    
    return rows.length > 0 ? rows[0] : null;
  } catch (error) {
    connection.release();
    logger.error('Error in DeliveryRequest.findClosestAvailableDriver', error);
    throw error;
  }
}

/**
 * Get all available drivers within radius of a location
 * @param {number} lat - Center latitude
 * @param {number} lng - Center longitude
 * @param {number} radiusMeters - Search radius in meters
 * @returns {array} - List of drivers with distance
 */
static async findDriversNearLocation(lat, lng, radiusMeters = 10000) {
  const connection = await pool.getConnection();
  try {
    const sql = `
      SELECT 
        id, uid, name, email, phone, latitude, longitude, is_working,
        (6371000 * ACOS(
          COS(RADIANS(?)) * COS(RADIANS(latitude)) * COS(RADIANS(longitude) - RADIANS(?))
          + SIN(RADIANS(?)) * SIN(RADIANS(latitude))
        )) AS distance
      FROM delivery_requests
      WHERE status = 'Approved'
        AND is_working = 1
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
      HAVING distance <= ?
      ORDER BY distance ASC`;

    const [rows] = await connection.execute(sql, [lat, lng, lat, radiusMeters]);
    connection.release();
    return rows;
  } catch (error) {
    connection.release();
    logger.error('Error in DeliveryRequest.findDriversNearLocation', error);
    throw error;
  }
}

/**
 * Get all drivers with their locations (for admin dashboard map)
 */
static async getAllWithLocations() {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(`
      SELECT id, uid, name, email, phone, status, is_working, latitude, longitude,
        DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') as last_updated
      FROM delivery_requests
      WHERE status = 'Approved'
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
      ORDER BY is_working DESC, updated_at DESC`);
    connection.release();
    return rows;
  } catch (error) {
    connection.release();
    logger.error('Error in DeliveryRequest.getAllWithLocations', error);
    throw error;
  }
}

/**
 * Record a completed delivery for driver stats
 * @param {string} driverUid - Driver UID
 * @param {number} orderId - Order ID
 * @param {number} earnings - Driver earnings for this delivery
 */
static async recordCompletedDelivery(driverUid, orderId, earnings) {
  const connection = await pool.getConnection();
  try {
    // Update driver's total deliveries and earnings
    // First check if columns exist, if not this will just update the timestamp
    await connection.execute(`
      UPDATE delivery_requests 
      SET 
        total_deliveries = COALESCE(total_deliveries, 0) + 1,
        total_earnings = COALESCE(total_earnings, 0) + ?,
        updated_at = NOW()
      WHERE uid = ?`,
      [earnings, driverUid]
    );
    connection.release();
    return true;
  } catch (error) {
    connection.release();
    // If columns don't exist, just log and continue
    if (error.code === 'ER_BAD_FIELD_ERROR') {
      logger.warn('Stats columns not found in delivery_requests table. Skipping stats update.');
      return true;
    }
    logger.error('Error in DeliveryRequest.recordCompletedDelivery', error);
    throw error;
  }
}

/**
 * Get driver statistics
 * @param {string} driverUid - Driver UID
 * @param {object} options - Filter options (month, year)
 */
static async getDriverStats(driverUid, options = {}) {
  const connection = await pool.getConnection();
  try {
    // Get basic driver info
    const [driverRows] = await connection.execute(
      'SELECT * FROM delivery_requests WHERE uid = ?',
      [driverUid]
    );

    if (driverRows.length === 0) {
      connection.release();
      return null;
    }

    const driver = driverRows[0];

    // Build date filter for orders
    let dateFilter = '';
    const params = [driverUid];

    if (options.month && options.year) {
      dateFilter = 'AND MONTH(delivered_at) = ? AND YEAR(delivered_at) = ?';
      params.push(options.month, options.year);
    } else if (options.year) {
      dateFilter = 'AND YEAR(delivered_at) = ?';
      params.push(options.year);
    }

    // Get delivery stats from orders table
    const [statsRows] = await connection.execute(`
      SELECT 
        COUNT(*) as total_deliveries,
        COALESCE(SUM(total_price * 0.10), 0) as total_earnings,
        COALESCE(AVG(total_price), 0) as avg_order_value
      FROM orders
      WHERE driver_id = ?
        AND status = 'delivered'
        ${dateFilter}`,
      params
    );

    // Get today's stats
    const [todayRows] = await connection.execute(`
      SELECT 
        COUNT(*) as deliveries_today,
        COALESCE(SUM(total_price * 0.10), 0) as earnings_today
      FROM orders
      WHERE driver_id = ?
        AND status = 'delivered'
        AND DATE(delivered_at) = CURDATE()`,
      [driverUid]
    );

    connection.release();

    const stats = statsRows[0] || {};
    const today = todayRows[0] || {};

    return {
      driver: {
        id: driver.id,
        uid: driver.uid,
        name: driver.name,
        email: driver.email,
        phone: driver.phone,
        status: driver.status,
        is_working: driver.is_working,
      },
      stats: {
        total_deliveries: parseInt(stats.total_deliveries) || 0,
        total_earnings: parseFloat(stats.total_earnings) || 0,
        avg_order_value: parseFloat(stats.avg_order_value) || 0,
        deliveries_today: parseInt(today.deliveries_today) || 0,
        earnings_today: parseFloat(today.earnings_today) || 0,
      },
      period: options.month && options.year 
        ? `${options.month}/${options.year}` 
        : options.year 
          ? `${options.year}` 
          : 'All Time',
    };
  } catch (error) {
    connection.release();
    logger.error('Error in DeliveryRequest.getDriverStats', error);
    throw error;
  }
}
}

export default DeliveryRequest;
