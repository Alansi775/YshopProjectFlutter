// lib/screens/admin/admins_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'common.dart';
import 'widgets.dart' as w;

// ═══════════════════════════════════════════════════════════════════════════════
// 👨‍💼 ADMINS MANAGEMENT VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class AdminsManagementView extends StatefulWidget {
  const AdminsManagementView({super.key});

  @override
  State<AdminsManagementView> createState() => _AdminsManagementViewState();
}

class _AdminsManagementViewState extends State<AdminsManagementView> {
  List<AdminModel> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getAdmins();
      if (mounted) {
        setState(() {
          _admins = (response as List?)?.map((a) => AdminModel.fromMap(a)).toList() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admins: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddAdminDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddAdminDialog(
        onAdd: (firstName, lastName, password) async {
          try {
            await ApiService.createAdmin(
              firstName: firstName,
              lastName: lastName,
              password: password,
            );
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin created successfully'),
                  backgroundColor: kAccentGreen,
                ),
              );
              _loadAdmins();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteAdmin(AdminModel admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => w.GlassConfirmDialog(
        title: 'Delete Admin',
        message: 'Are you sure you want to delete "${admin.fullName}"? This will also remove all users associated with this admin.',
        confirmLabel: 'Delete',
        isDanger: true,
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await ApiService.deleteAdmin(admin.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${admin.fullName} deleted successfully'),
            backgroundColor: kAccentGreen,
          ),
        );
        _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  void _showAdminDetails(AdminModel admin) {
    showDialog(
      context: context,
      builder: (_) => _AdminDetailsDialog(admin: admin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
    if (role != 'superadmin') {
      return Center(
        child: Text('Access denied: Admins Management is restricted to superadmin.', style: TextStyle(color: kSecondaryTextColor)),
      );
    }
    return Column(
      children: [
        // Header with add button
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              w.SectionHeader(
                title: 'Admins',
                subtitle: '${_admins.length} admins registered',
              ),
              w.GradientButton(
                label: 'Add Admin',
                icon: Icons.person_add_rounded,
                onPressed: _showAddAdminDialog,
                gradient: AppGradients.primary,
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kAccentBlue))
              : _admins.isEmpty
                  ? Center(
                      child: w.EmptyStateView(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'No Admins Yet',
                        message: 'Add your first admin to get started.',
                        actionLabel: 'Add Admin',
                        onAction: _showAddAdminDialog,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAdmins,
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
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: _admins.length,
                            itemBuilder: (context, index) {
                              final admin = _admins[index];
                              return _AdminCard(
                                admin: admin,
                                onTap: () => _showAdminDetails(admin),
                                onDelete: () => _deleteAdmin(admin),
                              );
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 👨‍💼 ADMIN CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final AdminModel admin;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AdminCard({
    required this.admin,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = admin.role.toLowerCase() == 'superadmin';
    
    return w.GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and role badge
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: isSuperAdmin ? AppGradients.purple : AppGradients.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isSuperAdmin ? kAccentPurple : kAccentBlue).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    admin.fullName.isNotEmpty ? admin.fullName[0].toUpperCase() : 'A',
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
                      admin.fullName,
                      style: const TextStyle(
                        color: kPrimaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _RoleBadge(role: admin.role),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Info
          _InfoRow(icon: Icons.email_rounded, text: admin.email),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            text: admin.createdAt != null
                ? 'Joined ${admin.createdAt!.day}/${admin.createdAt!.month}/${admin.createdAt!.year}'
                : 'N/A',
          ),
          
          const Spacer(),
          
          // Actions
          const Divider(color: kSeparatorColor, height: 24),
          Row(
            children: [
              Expanded(
                child: w.GlassOutlineButton(
                  label: 'View Details',
                  icon: Icons.visibility_rounded,
                  onPressed: onTap,
                  color: kAccentBlue,
                  isSmall: true,
                ),
              ),
              const SizedBox(width: 8),
              if (!isSuperAdmin)
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

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = role.toLowerCase() == 'superadmin';
    final color = isSuperAdmin ? kAccentPurple : kAccentBlue;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuperAdmin ? Icons.shield_rounded : Icons.admin_panel_settings_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isSuperAdmin ? 'Super Admin' : 'Admin',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
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
// ➕ ADD ADMIN DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AddAdminDialog extends StatefulWidget {
  final Function(String firstName, String lastName, String password) onAdd;

  const _AddAdminDialog({required this.onAdd});

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String get _generatedEmail {
    final firstName = _firstNameController.text.trim().toLowerCase();
    final lastName = _lastNameController.text.trim().toLowerCase();
    if (firstName.isEmpty && lastName.isEmpty) return '';
    return '$firstName.$lastName@yshop.com';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    widget.onAdd(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: w.GlassContainer(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Add New Admin',
                      style: TextStyle(
                        color: kPrimaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: kSecondaryTextColor),
                    ),
                  ],
                ),
                
                const SizedBox(height: 28),
                
                // First name
                w.GlassTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  hint: 'Enter first name',
                  prefixIcon: Icons.person_rounded,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                
                const SizedBox(height: 16),
                
                // Last name
                w.GlassTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  hint: 'Enter last name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                
                const SizedBox(height: 16),
                
                // Generated email preview
                AnimatedBuilder(
                  animation: Listenable.merge([_firstNameController, _lastNameController]),
                  builder: (context, _) {
                    final email = _generatedEmail;
                    if (email.isEmpty) return const SizedBox.shrink();
                    
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kAccentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kAccentBlue.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_rounded, color: kAccentBlue, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto-generated Email',
                                  style: TextStyle(color: kSecondaryTextColor, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: kAccentBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Password
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Password',
                      style: TextStyle(
                        color: kSecondaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kGlassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGlassBorder, width: 1),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: kPrimaryTextColor),
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Required';
                          if (v!.length < 6) return 'Min 6 characters';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          hintStyle: const TextStyle(color: kTertiaryTextColor),
                          prefixIcon: const Icon(Icons.lock_rounded, color: kSecondaryTextColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: kSecondaryTextColor,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 28),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: w.GlassOutlineButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        color: kSecondaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: w.GradientButton(
                        label: 'Create Admin',
                        icon: Icons.check_rounded,
                        onPressed: _submit,
                        gradient: AppGradients.success,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📋 ADMIN DETAILS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AdminDetailsDialog extends StatelessWidget {
  final AdminModel admin;

  const _AdminDetailsDialog({required this.admin});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = admin.role.toLowerCase() == 'superadmin';
    
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
                      gradient: isSuperAdmin ? AppGradients.purple : AppGradients.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        admin.fullName.isNotEmpty ? admin.fullName[0].toUpperCase() : 'A',
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
                          admin.fullName,
                          style: const TextStyle(
                            color: kPrimaryTextColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RoleBadge(role: admin.role),
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
              _DetailItem(label: 'Email', value: admin.email, icon: Icons.email_rounded),
              _DetailItem(label: 'First Name', value: admin.firstName, icon: Icons.person_rounded),
              _DetailItem(label: 'Last Name', value: admin.lastName, icon: Icons.person_outline_rounded),
              _DetailItem(label: 'Role', value: admin.role, icon: Icons.shield_rounded),
              _DetailItem(label: 'Admin ID', value: admin.id, icon: Icons.tag_rounded),
              if (admin.createdAt != null)
                _DetailItem(
                  label: 'Created At',
                  value: '${admin.createdAt!.day}/${admin.createdAt!.month}/${admin.createdAt!.year}',
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