import pool from '../config/database.js';
import logger from '../config/logger.js';

/**
 * Category Model
 */
export class Category {
  static async findAll() {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute(
        'SELECT * FROM categories ORDER BY name ASC'
      );
      connection.release();
      return rows;
    } catch (error) {
      logger.error('Error fetching categories:', error);
      throw error;
    }
  }

  static async create(name, description) {
    try {
      const connection = await pool.getConnection();
      const [result] = await connection.execute(
        `INSERT INTO categories (name, description, created_at) 
         VALUES (?, ?, NOW())`,
        [name, description]
      );
      connection.release();
      return { id: result.insertId, name, description };
    } catch (error) {
      logger.error('Error creating category:', error);
      throw error;
    }
  }
}

export default Category;
