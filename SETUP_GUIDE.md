# YShop - Complete Setup Guide

## 📋 Architecture Overview

```
YShop System:
├── Backend Server (Node.js + Express)
│   └── MySQL Database (Local)
│
├── Firebase
│   └── Authentication & Email Verification Only
│
└── Flutter App
    └── Communicates with Backend Server
```

## Setup Instructions

### Part 1: Backend Server Setup

#### Prerequisites
- Node.js (v16+)
- MySQL Server (v8.0+)
- npm

#### Steps

1. **Navigate to backend folder**
```bash
cd backend
```

2. **Install dependencies**
```bash
npm install
```

3. **Create `.env` file**
```bash
cp .env.example .env
```

4. **Edit `.env` with your credentials**
```env
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=yshop_db

# Server
NODE_ENV=development
PORT=3000
API_BASE_URL=http://localhost:3000

# Firebase (from your Firebase console)
FIREBASE_PROJECT_ID=home-720ef
FIREBASE_PRIVATE_KEY_ID=...
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_CLIENT_ID=...
```

5. **Create MySQL database**
```bash
mysql -u root -p
CREATE DATABASE yshop_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;
```

6. **Initialize database tables**
```bash
npm run migrate
```

7. **Start development server**
```bash
npm run dev
```

Server should run on `http://localhost:3000`

---

### Part 2: Flutter App Setup

1. **Update API URL in Flutter**
   - Edit [lib/services/api_service.dart](lib/services/api_service.dart)
   - Change `_baseUrl` if running on different IP/port

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
flutter run
```

---

## 📁 Backend Project Structure

```
backend/
├── src/
│   ├── config/              # Database & Firebase config
│   ├── middleware/          # Auth, validation, error handling
│   ├── models/              # Database models
│   ├── controllers/         # Business logic
│   ├── routes/              # API routes
│   ├── utils/               # Helper functions
│   └── server.js           # Main server file
├── database/
│   └── migrations/          # Database initialization
├── uploads/                 # Image storage
│   ├── products/
│   └── stores/
├── logs/                    # Application logs
├── package.json
├── .env.example
└── README.md
```

---

## 🔒 Database Schema

### users
- uid (Firebase UID)
- email
- display_name
- phone
- address
- created_at

### stores
- name
- description
- phone
- address
- latitude, longitude (for maps)
- icon_url
- is_active
- created_at

### products
- name
- description
- price
- store_id (FK)
- category_id
- stock
- image_url
- is_active
- created_at

### orders
- user_id (FK)
- store_id (FK)
- total_price
- status (pending, confirmed, shipped, delivered, cancelled)
- shipping_address
- created_at

### order_items
- order_id (FK)
- product_id (FK)
- quantity
- price

---

## 🛡️ Security Features

 **Firebase Token Verification**
- Every API request verified against Firebase tokens
- Only authenticated users can modify data

 **Rate Limiting**
- 100 requests per 15 minutes per IP
- Prevents brute force attacks

 **Input Validation**
- All inputs validated before processing
- Protection against SQL injection

 **CORS Enabled**
- Configured for Flutter app

 **Helmet.js**
- Security headers included

---

## ⚡ Performance Features

 **Connection Pooling**
- 20 concurrent MySQL connections
- Handles high traffic smoothly

 **Database Indexes**
- Optimized queries on frequently searched columns
- Full-text search on product names/descriptions

 **Response Compression**
- Gzip compression for responses

 **Caching Ready**
- Can integrate Redis for caching

---

## 📱 API Usage Examples

### Get Products
```dart
final products = await ApiService.getProducts(
  page: 1,
  limit: 20,
  storeId: 'store_123',
);
```

### Create Order (requires auth)
```dart
final order = await ApiService.createOrder(
  storeId: '1',
  totalPrice: 99.99,
  shippingAddress: 'Street 123, City',
  items: [
    {'productId': '1', 'quantity': 2, 'price': 25.50},
    {'productId': '2', 'quantity': 1, 'price': 48.99},
  ],
);
```

### Get User Profile (requires auth)
```dart
final profile = await ApiService.getUserProfile();
```

---

## 🐛 Troubleshooting

### "Connection refused" error
- Make sure MySQL is running
- Check DB credentials in `.env`

### "Firebase token invalid"
- Make sure user is signed in via Firebase
- Check Firebase config in `.env`

### "Too many requests"
- Wait 15 minutes for rate limit to reset
- Check IP address

---

## 🚢 Production Deployment

### Option 1: Using PM2
```bash
npm install -g pm2
pm2 start src/server.js --name yshop-backend
pm2 save
pm2 startup
```

### Option 2: Using Docker
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "src/server.js"]
```

```bash
docker build -t yshop-backend .
docker run -p 3000:3000 --env-file .env yshop-backend
```

---

## 📊 Monitoring

Check logs:
```bash
tail -f logs/combined.log
tail -f logs/error.log
```

Health check:
```bash
curl http://localhost:3000/health
```

---

## ❓ Questions?

Refer to:
- [backend/README.md](backend/README.md)
- Backend API documentation
- Flutter ApiService class

