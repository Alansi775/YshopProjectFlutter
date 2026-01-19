# System Testing Guide 🧪

## Before Testing

1. **Start Backend Server:**
```bash
cd backend
npm run dev
```
 Should see:
```
⚠️ Firebase Admin initialization DISABLED - Using MySQL API only
 Server running on http://localhost:3000
 Database connected successfully
⚠️ Firestore sync DISABLED - Using MySQL API only for store updates
```

2. **Start Flutter App:**
```bash
cd ..
flutter run -d web  # or your target device
```

---

## Test 1: Logout Clears Cache 

### Steps:
1. Open app → **Sign In** as User A (any test user)
2. Navigate to **Orders** tab (wait for data to load)
3. Open **DevTools** → Network tab (or use Chrome DevTools)
4. Click **Logout** in sidebar
5. Verify:
   -  Cart is empty
   -  No orders showing
   -  Redirected to Sign In screen
6. **Sign In** again as User A
7. Verify:
   -  Orders reload fresh from API
   -  No stale data visible

### Expected Network Calls on Logout:
```
[No additional requests should appear]
[Previous cache should be cleared]
```

---

## Test 2: Switch Users Without Logout 

### Steps:

**Part A: User A Sets Data**
1. Sign In as **User A** (Customer with items in cart)
2. Go to **Home** tab
3. Note the products/orders visible
4. Open browser console and note cart items

**Part B: Switch to User B**
1. Without logging out, open **Incognito/Private Window**
2. Sign In as **User B** (different customer)
3. Verify:
   -  Cart is DIFFERENT from User A
   -  Different orders/products visible
   -  No User A's data visible
4. Go to Original Window (still logged in as User A)
5. Verify:
   -  User A's data still intact
   -  No contamination from User B

### Debug Check:
```javascript
// In browser console (for each user):
console.log('Current UID:', await ApiService._getFirebaseToken());
// Should show different tokens for different users
```

---

## Test 3: Admin to Customer Switch 

### Steps:

**Part A: Admin Dashboard**
1. Sign In as **Admin** 
   - Email: `admin@yshop.com` or similar
   - Password: [admin password]
2. View **Dashboard** → Note:
   - Store counts
   - Order counts
   - Product counts
3. Note the quick stats numbers

**Part B: Switch to Customer**
1. Logout from admin
2. Sign In as **Customer**
3. Verify:
   -  Admin dashboard NOT visible
   -  Customer dashboard (Orders, Products) visible
   -  Different data structure

**Part C: Back to Admin**
1. Sign Out
2. Sign In as Admin again
3. Verify:
   -  Dashboard stats match original values
   -  All admin features working

---

## Test 4: Rapid Store Operations 

### Setup:
- Sign in as **Admin**
- Navigate to **Stores** tab

### Steps:
1. Open **DevTools** → **Network** tab
2. Open **Console** and enable logging
3. **Rapidly click:** Approve/Suspend buttons on stores
4. Observe:
   -  Buttons should debounce (not send duplicate requests)
   -  Each action takes 1-2 seconds (not instant)
   -  Status updates correctly

### Expected Behavior:
```
Click Approve Button
  → 1 request sent to API
  → Status changes in UI (optimistic)
  → API responds
  → Counts update

Rapid Clicks (Approve, Suspend, Approve):
  → Only LAST action gets sent
  → No duplicate requests
  → No "Too Many Requests" error
```

---

## Test 5: Cart Operations 

### Steps:

**Add to Cart:**
1. Sign In as **Customer**
2. Navigate to **Products**
3. Click **Add to Cart** on multiple products
4. Verify:
   -  Cart count increases
   -  Products appear in cart

**Logout & Login:**
1. Click **Logout**
2. Verify:
   -  Cart disappears
   -  `CartManager.clearCart()` was called
3. Sign In again
4. Verify:
   -  Cart is EMPTY (not persisted after logout)

---

## Test 6: Concurrent Requests 

### Prerequisites:
- Multiple browser tabs open with app
- Multiple logged-in users (if possible)

### Steps:

**Tab 1 - Admin:**
1. Logged in as Admin
2. Do nothing (just keep logged in)

**Tab 2 - Admin (different window):**
1. Open new tab → Sign In as Admin
2. Should work WITHOUT errors

**Tab 3 - Customer:**
1. Open another tab → Sign In as Customer
2. Switch back to Tab 2 (Admin)
3. Verify:
   -  Admin tab still shows admin data
   -  Customer tab shows customer data
   -  No "Unauthorized" errors

### Expected Requests:
- Each tab has its own token
- Each token is independently validated
- No cross-contamination

---

## Test 7: Server Restart Recovery 

### Steps:

1. **Login as User**
   - Sign In (note you're logged in)
   
2. **Restart Backend Server**
   - In backend terminal: Stop server (Ctrl+C)
   - Wait 2 seconds
   - Restart: `npm run dev`

3. **Test App**
   - Should auto-reconnect (or show error)
   - Click any button to retry
   - Verify:
     -  No ghost data persists
     -  Fresh request sent to restarted server
     -  Normal operation resumes

---

## Test 8: Network Offline → Online 

### Steps:

1. **Open DevTools** → **Network** tab
2. **Throttle Connection:**
   - Network Speed: **Slow 3G** or **Offline**
3. **Try an Operation:**
   - Approve a store
   - Add to cart
   - Place order
4. **Expected:** 
   -  Timeout or error
   -  UI shows error message
5. **Restore Connection:**
   - Change throttle back to **No Throttle**
   - Retry operation
   -  Should succeed

---

## Logging / Debugging

### Frontend Console:

```javascript
// Check current token
const token = await ApiService._getFirebaseToken();
console.log('Current Token:', token?.substring(0, 50) + '...');

// Check cache status
console.log('Cache Stats:', ApiService.getCacheStats());

// Check pending requests
// (Not directly exposed, but evident in Network tab)

// Monitor logout
ApiService.clearCache(); // Should see console logs
```

### Backend Logs:

```bash
# Watch logs while testing
tail -f backend/logs/* 2>/dev/null || echo "No logs yet"

# Look for:
 "User 123 synced to MySQL"
❌ "Unauthorized: Invalid or expired token"
⚠️ "Too many requests from this user"
 "Store 251 MySQL updated to Approved"
```

---

## Common Issues & Solutions

### Issue: "Unauthorized: Invalid or expired token"
**Cause:** Token expired or cleared
**Fix:** 
- Logout and login again
- Check browser storage is not corrupted
- Restart app

### Issue: "Too many requests from this user"
**Cause:** Hitting rate limit (100 req/min per user)
**Fix:**
- Normal, rate limiting is working
- Wait 1 minute and retry
- Check for infinite request loops in code

### Issue: "Connection error: Failed to fetch"
**Cause:** Backend down or network issue
**Fix:**
- Check `npm run dev` is running in backend
- Check frontend → backend URL correct
- Check CORS headers

### Issue: Old user data showing after login
**Cause:** Cache not cleared properly
**Fix:**
- Force refresh page (Cmd+Shift+R / Ctrl+Shift+R)
- Clear browser localStorage: DevTools → Application → Clear Storage
- Restart app

---

## Success Criteria 

After running all tests, you should see:

- [ ] **Test 1:** Logout completely clears state
- [ ] **Test 2:** User switching prevents data bleed
- [ ] **Test 3:** Admin/Customer roles isolated
- [ ] **Test 4:** Rapid operations don't flood backend
- [ ] **Test 5:** Cart clears on logout
- [ ] **Test 6:** Multiple sessions work independently
- [ ] **Test 7:** Server restart doesn't break app
- [ ] **Test 8:** Offline/online recovery works

**Result: System is production-ready! 🚀**

---

## Performance Benchmarks

### Expected Response Times:

| Operation | Time |
|-----------|------|
| Login | <2s |
| Logout | <500ms |
| Store Approve/Suspend | <1s |
| Dashboard Load | <2s |
| Product Search | <1s (debounced) |
| Add to Cart | <500ms |
| Switch User | <1s |

If significantly slower, check:
- Network throttling
- Browser DevTools open (slows down)
- Backend logs for slow queries
- Database connections

---

## Report Issues

If you find problems:

1. **Note the exact steps to reproduce**
2. **Check backend logs:**
   ```bash
   cat backend/logs/*.log | tail -100
   ```
3. **Check browser console for errors**
4. **Check Network tab in DevTools**
5. **Document:**
   - User role (admin/customer)
   - Device/browser
   - Reproduction steps
   - Expected vs actual behavior

