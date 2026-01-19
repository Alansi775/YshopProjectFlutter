// lib/screens/admin/stores_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/store.dart';
import '../stores/store_products_view.dart' as sp;
import 'common.dart';
import 'widgets.dart' as w;

// ═══════════════════════════════════════════════════════════════════════════════
//  STORES MANAGEMENT VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class StoresManagementView extends StatefulWidget {
  final void Function(StoreRequest store)? onOpenStore;
  final VoidCallback? onStoreUpdated; //  Callback to notify parent when store is updated
  final int initialTabIndex;

  const StoresManagementView({
    super.key,
    this.onOpenStore,
    this.onStoreUpdated,
    this.initialTabIndex = 0,
  });
  
  @override
  State<StoresManagementView> createState() => _StoresManagementViewState();
}

class _StoresManagementViewState extends State<StoresManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StoreRequest> _approvedStores = [];
  List<StoreRequest> _pendingStores = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, initialIndex: widget.initialTabIndex, vsync: this);
    _loadStores();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    try {
      //  Clear cache first to ensure fresh data
      ApiService.clearCache();
      
      final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
      List<dynamic> approvedResp = [];
      List<dynamic> pendingResp = [];

      if (role == 'user') {
        // regular users see public stores (approved only)
        approvedResp = await ApiService.getStores(page: 1, limit: 100);
        pendingResp = [];
      } else {
        approvedResp = await ApiService.getApprovedStores();
        pendingResp = await ApiService.getPendingStores();
      }
      
      if (mounted) {
        setState(() {
          //  FIX: Read status from API response, don't hardcode it!
          _approvedStores = (approvedResp as List?)?.map((s) => StoreRequest.fromMap({
            'id': s['id'],
            'owner_uid': s['owner_uid'],
            'name': s['name'],
            'store_type': s['store_type'],
            'address': s['address'],
            'email': s['email'],
            'icon_url': Store.getFullImageUrl(s['icon_url']),
            'phone': s['phone'],
            'status': s['status'] ?? 'Approved', //  Read from API, fallback to 'Approved'
          })).toList() ?? [];
          
          //  FIX: Read status from API response for pending stores too
          _pendingStores = (pendingResp as List?)?.map((s) => StoreRequest.fromMap({
            'id': s['id'],
            'owner_uid': s['owner_uid'],
            'name': s['name'],
            'store_type': s['store_type'],
            'address': s['address'],
            'email': s['email'],
            'icon_url': Store.getFullImageUrl(s['icon_url']),
            'phone': s['phone'],
            'status': s['status'] ?? 'Pending', //  Read from API, fallback to 'Pending'
          })).toList() ?? [];
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stores: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveStore(StoreRequest store) async {
    try {
      await ApiService.approveStore(store.id);
      if (mounted) {
        //  FIX: Create NEW StoreRequest with updated status = 'Approved'
        setState(() {
          _pendingStores.removeWhere((s) => s.id == store.id);
          //  Create a new object with the correct status
          final approvedStore = StoreRequest(
            id: store.id,
            ownerUid: store.ownerUid,
            storeName: store.storeName,
            storeType: store.storeType,
            address: store.address,
            email: store.email,
            storeIconUrl: store.storeIconUrl,
            storePhone: store.storePhone,
            status: 'Approved', //  Explicitly set to 'Approved'
          );
          _approvedStores.insert(0, approvedStore);
        });
        // Clear cache for next load
        ApiService.clearCache();
        //  Wait for backend to update before notifying parent
        // This prevents the Dashboard from showing stale data (increased to 1000ms for reliability)
        await Future.delayed(const Duration(milliseconds: 1000));
        //  Notify parent (Dashboard) to refresh counts
        widget.onStoreUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  Future<void> _rejectStore(StoreRequest store) async {
    try {
      await ApiService.suspendStore(store.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${store.storeName} suspended successfully'),
            backgroundColor: kAccentOrange,
          ),
        );
        //  FIX: Create NEW StoreRequest with updated status = 'Suspended'
        setState(() {
          _approvedStores.removeWhere((s) => s.id == store.id);
          //  Create a new object with the correct status
          final suspendedStore = StoreRequest(
            id: store.id,
            ownerUid: store.ownerUid,
            storeName: store.storeName,
            storeType: store.storeType,
            address: store.address,
            email: store.email,
            storeIconUrl: store.storeIconUrl,
            storePhone: store.storePhone,
            status: 'Suspended', //  Explicitly set to 'Suspended'
          );
          _pendingStores.insert(0, suspendedStore);
        });
        // Clear cache for next load
        ApiService.clearCache();
        //  Wait for backend to update before notifying parent
        // This prevents the Dashboard from showing stale data (increased to 1000ms for reliability)
        await Future.delayed(const Duration(milliseconds: 1000));
        //  Notify parent (Dashboard) to refresh counts
        widget.onStoreUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  Future<void> _deleteStore(StoreRequest store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => w.GlassConfirmDialog(
        title: 'Delete Store',
        message: 'Are you sure you want to delete "${store.storeName}"? This will also delete all products associated with this store.',
        confirmLabel: 'Delete',
        isDanger: true,
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await ApiService.deleteStore(store.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${store.storeName} deleted successfully'),
            backgroundColor: kAccentGreen,
          ),
        );
        //  Optimistic: remove from list
        setState(() {
          _approvedStores.removeWhere((s) => s.id == store.id);
          _pendingStores.removeWhere((s) => s.id == store.id);
        });
        //  Only clear cache, don't reload (avoid race condition)
        ApiService.clearCache();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  void _viewStoreProducts(StoreRequest store) {
    if (widget.onOpenStore != null) {
      widget.onOpenStore!(store);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => sp.StoreProductsView(
          storeId: store.id,
          storeName: store.storeName,
        ),
      ),
    );
  }

  void _showStoreDetails(StoreRequest store) {
    showDialog(
      context: context,
      builder: (_) => _StoreDetailsDialog(store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: kGlassBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGlassBorder, width: 1),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            labelColor: Colors.white,
            unselectedLabelColor: kSecondaryTextColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Approved (${_approvedStores.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pending_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Pending (${_pendingStores.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Quick search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            style: const TextStyle(color: kPrimaryTextColor),
            decoration: InputDecoration(
              hintText: 'Search store name...',
              hintStyle: TextStyle(color: kSecondaryTextColor.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.search, color: kSecondaryTextColor),
              filled: true,
              fillColor: kCardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              setState(() {
                _searchQuery = v.trim().toLowerCase();
              });
            },
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kAccentBlue))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStoresList(_approvedStores, isApproved: true),
                    _buildStoresList(_pendingStores, isApproved: false),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStoresList(List<StoreRequest> stores, {required bool isApproved}) {
    final filtered = _searchQuery.isEmpty
        ? stores
        : stores.where((s) => s.storeName.toLowerCase().contains(_searchQuery)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: w.EmptyStateView(
          icon: isApproved ? Icons.storefront_rounded : Icons.pending_actions_rounded,
          title: isApproved ? 'No Approved Stores' : 'No Pending Requests',
          message: isApproved
              ? 'There are no approved stores yet.'
              : 'There are no pending store requests.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStores,
      color: kAccentBlue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1200
              ? 4
              : constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final store = filtered[index];
              return _StoreCard(
                store: store,
                isApproved: isApproved,
                onTap: () => _viewStoreProducts(store),
                onDetails: () => _showStoreDetails(store),
                onApprove: (() {
                  final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                  if (role == 'user') return null;
                  return isApproved ? null : () { _approveStore(store); };
                })(),
                onReject: (() {
                  final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                  if (role == 'user') return null;
                  return isApproved ? () { _rejectStore(store); } : null;
                })(),
                onDelete: (() {
                  final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                  if (role == 'superadmin') return () { _deleteStore(store); };
                  return null;
                })(),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STORE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  final StoreRequest store;
  final bool isApproved;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;

  const _StoreCard({
    required this.store,
    required this.isApproved,
    required this.onTap,
    required this.onDetails,
    this.onApprove,
    this.onReject,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return w.GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with image and status
          Row(
            children: [
              w.GlassImageContainer(
                imageUrl: store.storeIconUrl,
                size: 64,
                borderRadius: 14,
                fallbackIcon: Icons.storefront_rounded,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName,
                      style: const TextStyle(
                        color: kPrimaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.storeType,
                      style: const TextStyle(
                        color: kSecondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              w.StatusBadgeView(status: store.status),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Info rows
          _InfoRow(icon: Icons.location_on_rounded, text: store.address),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.email_rounded, text: store.email),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.phone_rounded, text: store.storePhone),
          
          const Spacer(),
          
          // Actions
          const Divider(color: kSeparatorColor, height: 24),
          Row(
            children: [
              if (!isApproved && onApprove != null)
                Expanded(
                  child: w.GradientButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    onPressed: onApprove!,
                    gradient: AppGradients.success,
                    isSmall: true,
                  ),
                ),
              if (isApproved && onReject != null) ...[
                Expanded(
                  child: w.GlassOutlineButton(
                    label: 'Suspend',
                    icon: Icons.pause_rounded,
                    onPressed: onReject!,
                    color: kAccentOrange,
                    isSmall: true,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              _ActionIconButton(
                icon: Icons.visibility_rounded,
                color: kAccentBlue,
                onTap: onDetails,
                tooltip: 'View Details',
              ),
              const SizedBox(width: 8),
              if (onDelete != null)
                _ActionIconButton(
                  icon: Icons.delete_rounded,
                  color: kAccentRed,
                  onTap: onDelete,
                  tooltip: 'Delete Store',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kTertiaryTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? 'N/A' : text,
            style: const TextStyle(color: kSecondaryTextColor, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📋 STORE DETAILS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _StoreDetailsDialog extends StatelessWidget {
  final StoreRequest store;

  const _StoreDetailsDialog({required this.store});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: w.GlassContainer(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  w.GlassImageContainer(
                    imageUrl: store.storeIconUrl,
                    size: 80,
                    borderRadius: 18,
                    fallbackIcon: Icons.storefront_rounded,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.storeName,
                          style: const TextStyle(
                            color: kPrimaryTextColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        w.StatusBadgeView(status: store.status, fontSize: 14),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: kSecondaryTextColor),
                  ),
                ],
              ),
              
              const SizedBox(height: 28),
              
              // Details
              _DetailItem(label: 'Store Type', value: store.storeType, icon: Icons.category_rounded),
              _DetailItem(label: 'Address', value: store.address, icon: Icons.location_on_rounded),
              _DetailItem(label: 'Email', value: store.email, icon: Icons.email_rounded),
              _DetailItem(label: 'Phone', value: store.storePhone, icon: Icons.phone_rounded),
              _DetailItem(label: 'Owner ID', value: store.ownerUid, icon: Icons.person_rounded),
              _DetailItem(label: 'Store ID', value: store.id, icon: Icons.tag_rounded),
              
              const SizedBox(height: 24),
              
              // Close button
              w.GradientButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
                gradient: AppGradients.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kGlassBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kAccentBlue, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: kTertiaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    color: kPrimaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}