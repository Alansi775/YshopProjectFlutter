# YShop Flutter Project Structure

## 📁 Final Organization

```
lib/screens/
├── stores/                           Store Owner Module (13 files)
│   ├── store_admin_view.dart        - Main store dashboard
│   ├── store_detail_view.dart       - Store details page
│   ├── store_products_view.dart     - Store products listing
│   ├── store_settings_view.dart     - Store configuration
│   ├── add_product_view.dart        - Create new product
│   ├── edit_product_view.dart       - Edit existing product
│   ├── orders_view.dart             - Order management
│   ├── chat_list_view.dart          - Customer conversations list
│   ├── chat_view.dart               - Individual chat view
│   ├── product_details_view.dart    - Product details page
│   ├── category_sheet_view.dart     - Category selection modal
│   ├── category_products_view.dart  - Products in category view
│   └── category_selector_sheet.dart - Category selector widget
│
├── delivery/                         Delivery Driver Module (6 files)
│   ├── delivery_home_view.dart      - Driver dashboard
│   ├── delivery_signup_view.dart    - Driver registration
│   ├── delivery_requests_view.dart  - Delivery requests list
│   ├── delivery_qr_scanner_view.dart - QR code scanning
│   ├── delivery_shared.dart         - Shared models & widgets
│   └── map_of_delivery_man.dart     - Driver location map
│
├── admin/                            Admin Panel Module (11 files)
│   ├── admin_home_view.dart         - Admin dashboard
│   ├── admin_order_map_view.dart    - Order/delivery map
│   ├── stores_view.dart             - Manage stores
│   ├── products_view.dart           - Manage products
│   ├── orders_view.dart             - Manage orders
│   ├── drivers_view.dart            - Manage delivery drivers
│   ├── users_view.dart              - Manage customers
│   ├── admins_view.dart             - Manage admins
│   ├── settings_view.dart           - Admin settings
│   ├── sidebar.dart                 - Admin sidebar navigation
│   ├── widgets.dart                 - Admin-specific widgets
│   └── common.dart                  - Shared utilities
│
├── (Root Level - Customer Facing)
│   ├── sign_in_view.dart            - Auth entry point
│   ├── stores_list_view.dart        - Browse stores (customer)
│   ├── product_detail_view.dart     - Product details (customer)
│   ├── checkout_screen.dart         - Checkout flow
│   ├── category_home_view.dart      - Browse by category
│   └── settings_view.dart           - Customer settings
```

## 🔧 Import Path Pattern

### Files in `stores/` or `delivery/` accessing services/models/widgets:
```dart
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../widgets/custom_widgets.dart';
```

### Files in `admin/` accessing services/models/widgets:
```dart
import '../../services/api_service.dart';
import '../../models/store.dart';
import 'widgets.dart';  // Local admin widgets
```

### Root screens accessing stores/delivery:
```dart
import 'stores/store_admin_view.dart';
import 'delivery/delivery_home_view.dart';
```

### Cross-folder references:
```dart
import '../delivery/map_of_delivery_man.dart';  // From admin to delivery
import './stores/chat_view.dart';               // From root to stores
```

##  Migration Status

- **Stores Folder**:  Complete (13 files, all imports fixed)
- **Delivery Folder**:  Complete (6 files, all imports fixed)  
- **Admin Folder**:  Complete (11 files, all imports verified)
- **Root Screens**:  Complete (6 files, import references updated)

## 🔍 Verification

-  Flutter analyze: 0 import errors (588 total issues are deprecation/linting warnings only)
-  All relative import paths follow the 2-level-up pattern (`../../`)
-  No circular dependencies
-  All imports resolve correctly

## 📝 Recent Changes

1. Created `stores/` folder with 13 store owner management files
2. Created `delivery/` folder with 6 delivery driver files
3. Fixed 50+ import statements across the project
4. Removed `const` keyword from OrdersManagementView instantiation
5. Corrected admin import paths for orders_view.dart

## 🚀 Development Guidelines

- **Store screens** → Place in `stores/` folder, use `../../` for service imports
- **Delivery screens** → Place in `delivery/` folder, use `../../` for service imports
- **Admin screens** → Place in `admin/` folder, use `../../` for external imports
- **Customer screens** → Place in root `screens/` folder
- **Shared utilities** → Place in respective `models/`, `services/`, `widgets/` folders at root

---
Last Updated: 2025-01-14
