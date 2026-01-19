// lib/screens/admin/drivers_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'common.dart';
import 'widgets.dart' as w;

// ═══════════════════════════════════════════════════════════════════════════════
// 🚴 DRIVERS MANAGEMENT VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class DriversManagementView extends StatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onDriverUpdated; //  Callback to notify parent when driver is updated

  const DriversManagementView({
    super.key,
    this.initialTabIndex = 0,
    this.onDriverUpdated,
  });

  @override
  State<DriversManagementView> createState() => _DriversManagementViewState();
}

class _DriversManagementViewState extends State<DriversManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DeliveryRequest> _activeDrivers = [];
  List<DeliveryRequest> _approvedDrivers = [];
  List<DeliveryRequest> _pendingDrivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, initialIndex: widget.initialTabIndex, vsync: this);
    _loadDrivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      //  Clear cache first to ensure fresh data
      ApiService.clearCache();
      
      final active = await ApiService.getActiveDeliveryRequests();
      final approved = await ApiService.getApprovedDeliveryRequests();
      final pending = await ApiService.getPendingDeliveryRequests();

      if (mounted) {
        setState(() {
          //  FIX: Read status from API response, don't hardcode it!
          _activeDrivers = (active as List?)?.map((d) => DeliveryRequest.fromMap(d)).toList() ?? [];
          _approvedDrivers = (approved as List?)?.map((d) => DeliveryRequest.fromMap(d)).toList() ?? [];
          _pendingDrivers = (pending as List?)?.map((d) => DeliveryRequest.fromMap(d)).toList() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveDriver(DeliveryRequest driver) async {
    try {
      await ApiService.approveDeliveryRequest(driver.id);
      if (mounted) {
        //  FIX: Create NEW DeliveryRequest with updated status = 'Approved'
        setState(() {
          _pendingDrivers.removeWhere((d) => d.id == driver.id);
          //  Create a new object with the correct status
          final approvedDriver = DeliveryRequest(
            id: driver.id,
            uid: driver.uid,
            name: driver.name,
            email: driver.email,
            phoneNumber: driver.phoneNumber,
            nationalID: driver.nationalID,
            address: driver.address,
            status: 'Approved', //  Explicitly set to 'Approved'
            isWorking: driver.isWorking,
            createdAt: driver.createdAt,
          );
          _approvedDrivers.insert(0, approvedDriver);
        });
        // Clear cache for next load
        ApiService.clearCache();
        ApiService.clearPendingRequests();
        //  Wait for backend to update before next action (same as stores)
        await Future.delayed(const Duration(milliseconds: 1000));
        //  Reload drivers immediately in this view to avoid cache issues
        await _loadDrivers();
        //  Notify parent (Dashboard) to refresh counts
        widget.onDriverUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  Future<void> _rejectDriver(DeliveryRequest driver) async {
    try {
      await ApiService.setDeliveryRequestPending(driver.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${driver.name} set to pending'),
            backgroundColor: kAccentOrange,
          ),
        );
        //  FIX: Create NEW DeliveryRequest with updated status = 'Pending'
        setState(() {
          _approvedDrivers.removeWhere((d) => d.id == driver.id);
          _activeDrivers.removeWhere((d) => d.id == driver.id);
          //  Create a new object with the correct status
          final pendingDriver = DeliveryRequest(
            id: driver.id,
            uid: driver.uid,
            name: driver.name,
            email: driver.email,
            phoneNumber: driver.phoneNumber,
            nationalID: driver.nationalID,
            address: driver.address,
            status: 'Pending', //  Explicitly set to 'Pending'
            isWorking: false, // When suspended, driver is not working
            createdAt: driver.createdAt,
          );
          _pendingDrivers.insert(0, pendingDriver);
        });
        // Clear cache for next load
        ApiService.clearCache();
        ApiService.clearPendingRequests();
        //  Wait for backend to update before next action (same as stores)
        await Future.delayed(const Duration(milliseconds: 1000));
        //  Reload drivers immediately in this view to avoid cache issues
        await _loadDrivers();
        //  Notify parent (Dashboard) to refresh counts
        widget.onDriverUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  Future<void> _deleteDriver(DeliveryRequest driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => w.GlassConfirmDialog(
        title: 'Delete Driver',
        message: 'Are you sure you want to delete "${driver.name}"?',
        confirmLabel: 'Delete',
        isDanger: true,
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await ApiService.deleteDeliveryRequest(driver.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${driver.name} deleted successfully'),
            backgroundColor: kAccentGreen,
          ),
        );
        //  Optimistic: remove from lists
        setState(() {
          _activeDrivers.removeWhere((d) => d.id == driver.id);
          _approvedDrivers.removeWhere((d) => d.id == driver.id);
          _pendingDrivers.removeWhere((d) => d.id == driver.id);
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

  void _showDriverDetails(DeliveryRequest driver) {
    showDialog(
      context: context,
      builder: (_) => _DriverDetailsDialog(driver: driver),
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
              gradient: AppGradients.cyan,
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
                    Text('Active (${_activeDrivers.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_add_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Approved (${_approvedDrivers.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pending_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Pending (${_pendingDrivers.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kAccentBlue))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDriversList(_activeDrivers, isApproved: true, label: 'Active'),
                    _buildDriversList(_approvedDrivers, isApproved: true, label: 'Approved'),
                    _buildDriversList(_pendingDrivers, isApproved: false, label: 'Pending'),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDriversList(List<DeliveryRequest> drivers, {required bool isApproved, required String label}) {
    if (drivers.isEmpty) {
      String title;
      String message;
      IconData icon;
      if (label == 'Active') {
        title = 'No Active Drivers';
        message = 'There are no active drivers yet.';
        icon = Icons.delivery_dining_rounded;
      } else if (label == 'Approved') {
        title = 'No Approved Drivers';
        message = 'There are no approved drivers yet.';
        icon = Icons.group_add_rounded;
      } else {
        title = 'No Pending Requests';
        message = 'There are no pending driver requests.';
        icon = Icons.person_add_rounded;
      }

      return Center(
        child: w.EmptyStateView(
          icon: icon,
          title: title,
          message: message,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDrivers,
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
              childAspectRatio: 0.9,
            ),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return _DriverCard(
                driver: driver,
                isApproved: isApproved,
                onTap: () => _showDriverDetails(driver),
                onApprove: (() {
                  final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                  if (role == 'user') return null;
                  return isApproved ? null : () => _approveDriver(driver);
                })(),
                onReject: (() {
                  final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                  if (role == 'user') return null;
                  return isApproved ? () => _rejectDriver(driver) : null;
                })(),
                onDelete: () {
                  final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                  if (role == 'user') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied'), backgroundColor: kAccentRed));
                    return;
                  }
                  _deleteDriver(driver);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🚴 DRIVER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final DeliveryRequest driver;
  final bool isApproved;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback onDelete;

  const _DriverCard({
    required this.driver,
    required this.isApproved,
    required this.onTap,
    this.onApprove,
    this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return w.GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and status
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: isApproved ? AppGradients.success : AppGradients.warning,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isApproved ? kAccentGreen : kAccentOrange).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        color: kPrimaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    w.StatusBadgeView(status: driver.status),
                  ],
                ),
              ),
              // Working status indicator
              if (isApproved)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: driver.isWorking
                        ? kAccentGreen.withOpacity(0.15)
                        : kTertiaryTextColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    driver.isWorking ? Icons.work_rounded : Icons.work_off_rounded,
                    color: driver.isWorking ? kAccentGreen : kTertiaryTextColor,
                    size: 18,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Info rows
          _InfoRow(icon: Icons.email_rounded, text: driver.email),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.phone_rounded, text: driver.phoneNumber),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.badge_rounded, text: driver.nationalID),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.location_on_rounded, text: driver.address),
          
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
              // If this is a pending request show a Reject button (deletes it),
              // otherwise show compact delete icon for approved drivers.
              if (!isApproved)
                Expanded(
                  child: w.GlassOutlineButton(
                    label: 'Reject',
                    icon: Icons.delete_rounded,
                    onPressed: onDelete,
                    color: kAccentRed,
                    isSmall: true,
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: kAccentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kAccentRed.withOpacity(0.3), width: 1),
                  ),
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_rounded, color: kAccentRed, size: 18),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete',
                  ),
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
        const SizedBox(width: 10),
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

// ─────────────────────────────────────────────────────────────────────────────
// 📋 DRIVER DETAILS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _DriverDetailsDialog extends StatelessWidget {
  final DeliveryRequest driver;

  const _DriverDetailsDialog({required this.driver});

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
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: AppGradients.cyan,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(
                            color: kPrimaryTextColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            w.StatusBadgeView(status: driver.status, fontSize: 14),
                            const SizedBox(width: 8),
                            if (driver.isWorking)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kAccentGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: kAccentGreen),
                                    SizedBox(width: 6),
                                    Text(
                                      'Working',
                                      style: TextStyle(
                                        color: kAccentGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
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
              _DetailItem(label: 'Email', value: driver.email, icon: Icons.email_rounded),
              _DetailItem(label: 'Phone', value: driver.phoneNumber, icon: Icons.phone_rounded),
              _DetailItem(label: 'National ID', value: driver.nationalID, icon: Icons.badge_rounded),
              _DetailItem(label: 'Address', value: driver.address, icon: Icons.location_on_rounded),
              _DetailItem(label: 'UID', value: driver.uid, icon: Icons.fingerprint_rounded),
              _DetailItem(label: 'Driver ID', value: driver.id, icon: Icons.tag_rounded),
              if (driver.createdAt != null)
                _DetailItem(
                  label: 'Registered',
                  value: '${driver.createdAt!.day}/${driver.createdAt!.month}/${driver.createdAt!.year}',
                  icon: Icons.calendar_today_rounded,
                ),
              
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
            child: Icon(icon, color: kAccentCyan, size: 18),
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