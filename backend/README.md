# YShop Backend API Documentation

## Setup Instructions

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Setup Environment Variables
```bash
cp .env.example .env
# Edit .env with your MySQL credentials and Firebase config
```

### 3. Initialize Database
```bash
npm run migrate
```

### 4. Start Server
```bash
# Development
npm run dev

# Production
npm start
```

## API Endpoints

### Products
- `GET /api/v1/products` - List all products
- `GET /api/v1/products/:id` - Get product by ID
- `POST /api/v1/products` - Create product (requires auth)
- `PUT /api/v1/products/:id` - Update product (requires auth)
- `DELETE /api/v1/products/:id` - Delete product (requires auth)

### Stores
- `GET /api/v1/stores` - List all stores
- `GET /api/v1/stores/:id` - Get store by ID
- `POST /api/v1/stores` - Create store (requires auth)
- `PUT /api/v1/stores/:id` - Update store (requires auth)
- `DELETE /api/v1/stores/:id` - Delete store (requires auth)

### Orders
- `POST /api/v1/orders` - Create order (requires auth)
- `GET /api/v1/orders/user/orders` - Get user orders (requires auth)
- `GET /api/v1/orders/:id` - Get order details (requires auth)
- `PUT /api/v1/orders/:id/status` - Update order status (requires auth)

### Users
- `GET /api/v1/users/profile` - Get user profile (requires auth)
- `PUT /api/v1/users/profile` - Update user profile (requires auth)
- `POST /api/v1/users/sync` - Sync user after Firebase signup

## Performance Optimizations

 Connection Pooling (20 concurrent connections)
 Database Indexes on frequently queried columns
 Request Compression
 Rate Limiting (100 requests per 15 minutes)
 CORS Enabled
 Error Handling & Logging
 Helmet.js for security headers

## Production Deployment

1. Update `.env` with production credentials
2. Set `NODE_ENV=production`
3. Update CORS origin to your domain
4. Use process manager (PM2) for better uptime:
   ```bash
   npm install -g pm2
   pm2 start src/server.js --name yshop-backend
   ```

