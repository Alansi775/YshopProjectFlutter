# Migration Guide: From Firebase to Local Backend

## 📊 What Changed?

###  Still Using Firebase (No Change Needed)
- User Authentication (Sign Up, Sign In, Sign Out)
- Email Verification
- Password Reset
- User UID generation

### ❌ Moved from Firebase to Local Backend
- **Products** (was in Firestore → now in MySQL)
- **Stores** (was in Firestore → now in MySQL)
- **Orders** (was in Firestore → now in MySQL)
- **Order Items** (was in Firestore → now in MySQL)
- **Product Images** (was in Cloud Storage → now on local server)
- **Store Icons** (was in Cloud Storage → now on local server)

---

##  Migration Steps

### Step 1: Update Flutter Dependencies

The `pubspec.yaml` remains mostly the same, but you can remove/keep these:

```yaml
# Keep these:
firebase_core: ^4.1.1
firebase_auth: ^6.1.0

# Remove if not using:
cloud_firestore: ^6.0.2          # No longer needed
firebase_storage: ^13.0.2        # No longer needed
```

### Step 2: Replace API Calls

**Before (Firebase/Firestore):**
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('products')
    .limit(20)
    .get();
```

**After (Local Backend):**
```dart
final products = await ApiService.getProducts(limit: 20);
```

### Step 3: Update Data Models

Your models should work as-is since we're using similar structures.

### Step 4: Add Providers for State Management

In your `main.dart`, update the providers:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthManager>(create: (_) => AuthManager()),
    ChangeNotifierProvider<ProductManager>(create: (_) => ProductManager()),
    ChangeNotifierProvider<StoreManager>(create: (_) => StoreManager()),
    ChangeNotifierProvider<OrderManager>(create: (_) => OrderManager()),
  ],
  child: MyApp(),
)
```

---

## 📝 API Endpoint Examples

### Get Products
```dart
// Old (Firestore)
final snapshot = await FirebaseFirestore.instance
    .collection('products')
    .where('storeId', isEqualTo: storeId)
    .get();

// New (Backend API)
final products = await ApiService.getProducts(storeId: storeId);
```

### Create Order
```dart
// Old (Firestore)
await FirebaseFirestore.instance.collection('orders').add({
  'userId': user.uid,
  'storeId': storeId,
  'totalPrice': total,
  'items': items,
  'createdAt': FieldValue.serverTimestamp(),
});

// New (Backend API)
final order = await ApiService.createOrder(
  storeId: storeId,
  totalPrice: total,
  shippingAddress: address,
  items: items,
);
```

### Get User Orders
```dart
// Old (Firestore)
final snapshot = await FirebaseFirestore.instance
    .collection('orders')
    .where('userId', isEqualTo: user.uid)
    .orderBy('createdAt', descending: true)
    .get();

// New (Backend API)
final orders = await ApiService.getUserOrders();
```

---

##  Image Handling Changes

### Product Images
**Before:** Uploaded to Firebase Cloud Storage
```dart
firebase_storage.ref('products/$filename').putFile(file)
```

**After:** Backend handles it automatically
```dart
// Just pass the file to the backend, it saves it
// Image URL returned: /uploads/products/{uuid}.jpg
```

### Accessing Images
**Before:**
```dart
Image.network(firebaseStorageUrl)
```

**After:**
```dart
Image.network('http://localhost:3000/uploads/products/xxx.jpg')
```

---

## 🔐 Authentication Flow

Still using Firebase for authentication:

1. User signs up with email → Firebase Auth
2. Firebase sends verification email
3. User verifies email
4. User signs in → Get Firebase ID Token
5. **New:** Backend automatically syncs user to database
6. Subsequent API calls include Firebase token in header

---

## 🧪 Testing the Migration

### 1. Start Backend Server
```bash
cd backend
npm run dev
```

Should see: ` Server running on http://localhost:3000`

### 2. Check Database Connection
```bash
curl http://localhost:3000/health
```

Response: `{ "status": "ok", "message": "Server is running" }`

### 3. Test API Endpoints
```bash
# Get all products (no auth needed)
curl http://localhost:3000/api/v1/products

# This should return: { "success": true, "data": [] }
```

### 4. Test in Flutter App
- Sign in with your Firebase account
- Navigate to products page
- Should see products from local backend

---

## ⚠️ Important Notes

### Existing Firebase Data
If you had existing data in Firestore:
1. You need to manually migrate it to MySQL
2. Or write a script to export from Firestore → MySQL

### Environment Configuration
Make sure `_baseUrl` in `ApiService` matches your backend:
```dart
static const String _baseUrl = 'http://localhost:3000/api/v1';
```

For production, change to your server IP/domain.

### Firebase Configuration
Still needed in `.env` for backend:
```env
FIREBASE_PROJECT_ID=home-720ef
FIREBASE_PRIVATE_KEY_ID=...
```

---

## 📚 Key Files Modified

-  [lib/services/api_service.dart](lib/services/api_service.dart) - New HTTP API client
-  [lib/state_management/auth_manager.dart](lib/state_management/auth_manager.dart) - Updated with backend sync
-  [lib/state_management/product_manager.dart](lib/state_management/product_manager.dart) - New
-  [lib/state_management/store_manager.dart](lib/state_management/store_manager.dart) - New
-  [lib/state_management/order_manager.dart](lib/state_management/order_manager.dart) - New
-  [backend/](backend/) - Complete new server implementation

---

## Performance Benefits

- **Faster Queries:** MySQL indexes on frequently searched columns
- **Better Scalability:** Connection pooling handles high concurrency
- **Lower Latency:** Local server vs Firebase cloud
- **Cost Saving:** No Firebase Firestore costs
- **Full Control:** Complete control over data and logic

---

## ❓ Troubleshooting

### "Cannot connect to backend"
```bash
# Check if backend is running
curl http://localhost:3000/health

# Check if MySQL is running
mysql -u root -p -e "SELECT 1"
```

### "Firebase token invalid"
- Make sure user is signed in
- Token refreshes automatically
- Check Firebase config

### "Products not loading"
- Check backend is running
- Check MySQL database has tables
- Check API logs: `tail -f logs/combined.log`

---

## 📞 Support

For issues:
1. Check backend logs
2. Check Flutter console logs
3. Test API endpoint directly with curl
4. Check database with MySQL client

