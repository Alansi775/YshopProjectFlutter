import { validationResult, body, param } from 'express-validator';
import logger from '../config/logger.js';

/**
 * Middleware للتحقق من نتائج validation
 */
export const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    logger.warn('Validation errors:', errors.array());
    return res.status(400).json({
      success: false,
      message: 'Validation error',
      errors: errors.array(),
    });
  }
  next();
};

/**
 * Validation rules للمنتجات
 */
export const validateProduct = [
  body('name').notEmpty().withMessage('Product name is required').trim(),
  body('description').optional().trim(),
  body('price').isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('storeId').notEmpty().withMessage('Store ID is required'),
  body('categoryId').optional().isInt(),
  body('stock').isInt({ min: 0 }).withMessage('Stock must be a non-negative number'),
  handleValidationErrors,
];

/**
 * Validation rules للمحلات
 */
export const validateStore = [
  body('name').notEmpty().withMessage('Store name is required').trim(),
  body('description').optional().trim(),
  body('phone').notEmpty().withMessage('Phone is required'),
  body('address').notEmpty().withMessage('Address is required').trim(),
  body('latitude').isFloat().withMessage('Latitude must be a number'),
  body('longitude').isFloat().withMessage('Longitude must be a number'),
  handleValidationErrors,
];

/**
 * Validation rules للـ pagination
 */
export const validatePagination = [
  body('page').optional().isInt({ min: 1 }).withMessage('Page must be >= 1'),
  body('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  handleValidationErrors,
];

export default {
  validateProduct,
  validateStore,
  validatePagination,
  handleValidationErrors,
};
