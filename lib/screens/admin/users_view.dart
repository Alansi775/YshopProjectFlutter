// lib/screens/admin/users_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'common.dart';
import 'widgets.dart' as w;

// ═══════════════════════════════════════════════════════════════════════════════
// 👥 USERS MANAGEMENT VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class UsersManagementView extends StatefulWidget {
  const UsersManagementView({super.key});

  @override
  State<UsersManagementView> createState() => _UsersManagementViewState();
}

class _UsersManagementViewState extends State<UsersManagementView> {
  List<UserModel> _users = [];
  List<AdminModel> _admins = [];
  bool _isLoading = true;
  String? _selectedAdminId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse = await ApiService.getUsers();
      final adminsResponse = await ApiService.getAdmins();
      
      if (mounted) {
        setState(() {
          _users = (usersResponse as List?)?.map((u) => UserModel.fromMap(u)).toList() ?? [];
          _admins = (adminsResponse as List?)?.map((a) => AdminModel.fromMap(a)).toList() ?? [];
          final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
          // If current user is an admin (not superadmin), show only users under this admin
          if (role == 'admin') {
            final myAdminId = ApiService.cachedAdminId;
            if (myAdminId != null) {
              _users = _users.where((u) => u.adminId == myAdminId).toList();
              _admins = _admins.where((a) => a.id == myAdminId).toList();
              _selectedAdminId = myAdminId;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<UserModel> get _filteredUsers {
    if (_selectedAdminId == null) return _users;
    return _users.where((u) => u.adminId == _selectedAdminId).toList();
  }

  String _getAdminName(String adminId) {
    final admin = _admins.firstWhere(
      (a) => a.id == adminId,
      orElse: () => AdminModel(id: '', email: '', firstName: 'Unknown', lastName: 'Admin', role: ''),
    );
    return admin.fullName;
  }

  void _showAddUserDialog() {
    if (_admins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create an admin first'),
          backgroundColor: kAccentOrange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (_) => _AddUserDialog(
        admins: _admins,
        onAdd: (firstName, lastName, password, adminId) async {
          try {
            await ApiService.createUser(
              firstName: firstName,
              lastName: lastName,
              password: password,
              adminId: adminId,
            );
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User created successfully'),
                  backgroundColor: kAccentGreen,
                ),
              );
              _loadData();
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

  Future<void> _deleteUser(UserModel user) async {
    final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
    final myAdminId = ApiService.cachedAdminId;
    if (role == 'user') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied'), backgroundColor: kAccentRed));
      return;
    }
    if (role == 'admin' && myAdminId != null && user.adminId != myAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only delete your own users'), backgroundColor: kAccentRed));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => w.GlassConfirmDialog(
        title: 'Delete User',
        message: 'Are you sure you want to delete "${user.fullName}"?',
        confirmLabel: 'Delete',
        isDanger: true,
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await ApiService.deleteUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} deleted successfully'),
            backgroundColor: kAccentGreen,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed),
        );
      }
    }
  }

  Future<void> _toggleBan(UserModel user) async {
    final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
    final myAdminId = ApiService.cachedAdminId;
    if (role == 'user') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied'), backgroundColor: kAccentRed));
      return;
    }
    if (role == 'admin' && myAdminId != null && user.adminId != myAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only modify your own users'), backgroundColor: kAccentRed));
      return;
    }

    final newStatus = (user.status.toLowerCase() == 'banned') ? 'active' : 'banned';
    final actionLabel = newStatus == 'banned' ? 'Ban' : 'Approve';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => w.GlassConfirmDialog(
        title: '$actionLabel User',
        message: 'Are you sure you want to $actionLabel "${user.fullName}"?',
        confirmLabel: actionLabel,
        isDanger: newStatus == 'banned',
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.updateUserStatus(user.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.fullName} ${newStatus == 'banned' ? 'banned' : 'approved'}'), backgroundColor: kAccentGreen),
        );
        _loadData();
      }
    } on ApiException catch (ae) {
      if (mounted) {
        if (ae.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found'), backgroundColor: kAccentOrange));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${ae.message}'), backgroundColor: kAccentRed));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kAccentRed));
    }
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => _UserDetailsDialog(
        user: user,
        adminName: _getAdminName(user.adminId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filter and add button
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  w.SectionHeader(
                    title: 'Users',
                    subtitle: '${_filteredUsers.length} users (View-only access)',
                  ),
                  Builder(builder: (_) {
                    final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                    final canAdd = role != 'user';
                    return w.GradientButton(
                      label: 'Add User',
                      icon: Icons.person_add_rounded,
                      onPressed: canAdd ? _showAddUserDialog : null,
                      gradient: AppGradients.cyan,
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // Admin filter
              // Admin filter (only visible to superadmin)
              Builder(builder: (_) {
                final role = ApiService.cachedAdminRole?.toLowerCase() ?? 'admin';
                if (role == 'superadmin') {
                  return _buildAdminFilter();
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kAccentBlue))
              : _users.isEmpty
                  ? Center(
                      child: w.EmptyStateView(
                        icon: Icons.people_rounded,
                        title: 'No Users Yet',
                        message: 'Add users to give them view-only access to the dashboard.',
                        actionLabel: 'Add User',
                        onAction: _showAddUserDialog,
                      ),
                    )
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: w.EmptyStateView(
                            icon: Icons.filter_list_off_rounded,
                            title: 'No Users Found',
                            message: 'No users found for the selected admin.',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
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
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  return _UserCard(
                                    user: user,
                                    adminName: _getAdminName(user.adminId),
                                    onTap: () => _showUserDetails(user),
                                    onToggleBan: () => _toggleBan(user),
                                    onDelete: () => _deleteUser(user),
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

  Widget _buildAdminFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All filter
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _selectedAdminId == null,
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('All Admins'),
                ],
              ),
              labelStyle: TextStyle(
                color: _selectedAdminId == null ? Colors.white : kSecondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: kGlassBackground,
              selectedColor: kAccentCyan,
              side: BorderSide(
                color: _selectedAdminId == null ? kAccentCyan : kGlassBorder,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (_) {
                setState(() => _selectedAdminId = null);
              },
            ),
          ),
          // Admin filters
          ..._admins.map((admin) {
            final isSelected = _selectedAdminId == admin.id;
            final userCount = _users.where((u) => u.adminId == admin.id).length;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(admin.fullName),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.2) : kGlassBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$userCount',
                        style: TextStyle(
                          color: isSelected ? Colors.white : kSecondaryTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : kSecondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: kGlassBackground,
                selectedColor: kAccentBlue,
                side: BorderSide(
                  color: isSelected ? kAccentBlue : kGlassBorder,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (_) {
                  setState(() => _selectedAdminId = admin.id);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserModel user;
  final String adminName;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onToggleBan;

  const _UserCard({
    required this.user,
    required this.adminName,
    required this.onTap,
    this.onToggleBan,
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
          // Avatar and role badge
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppGradients.cyan,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
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
                      user.fullName,
                      style: const TextStyle(
                        color: kPrimaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _RoleBadge(role: user.role),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Info
          _InfoRow(icon: Icons.email_rounded, text: user.email),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.admin_panel_settings_rounded, text: 'Admin: $adminName'),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            text: user.createdAt != null
                ? 'Joined ${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
                : 'N/A',
          ),
          
          const Spacer(),
          
          // Permission info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kAccentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccentOrange.withOpacity(0.3), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_rounded, color: kAccentOrange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'View-only access',
                    style: TextStyle(
                      color: kAccentOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Actions
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
              // Ban/Approve toggle
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: onToggleBan != null ? kAccentOrange.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: onToggleBan != null ? Border.all(color: kAccentOrange.withOpacity(0.3), width: 1) : null,
                ),
                child: IconButton(
                  onPressed: onToggleBan,
                  icon: Icon(
                    user.status.toLowerCase() == 'banned' ? Icons.check_circle_rounded : Icons.block_rounded,
                    color: user.status.toLowerCase() == 'banned' ? kAccentGreen : kAccentOrange,
                    size: 18,
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: user.status.toLowerCase() == 'banned' ? 'Approve' : 'Ban',
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kAccentCyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccentCyan.withOpacity(0.3), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 12, color: kAccentCyan),
          SizedBox(width: 4),
          Text(
            'User',
            style: TextStyle(
              color: kAccentCyan,
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
        Icon(icon, size: 14, color: kTertiaryTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? 'N/A' : text,
            style: const TextStyle(color: kSecondaryTextColor, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ➕ ADD USER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AddUserDialog extends StatefulWidget {
  final List<AdminModel> admins;
  final Function(String firstName, String lastName, String password, String adminId) onAdd;

  const _AddUserDialog({
    required this.admins,
    required this.onAdd,
  });

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedAdminId;
  bool _isLoading = false;
  bool _obscurePassword = true;

  String get _generatedEmail {
    final firstName = _firstNameController.text.trim().toLowerCase();
    final lastName = _lastNameController.text.trim().toLowerCase();
    if (firstName.isEmpty && lastName.isEmpty) return '';
    return '$firstName.$lastName@yshop.com';
  }

  @override
  void initState() {
    super.initState();
    if (widget.admins.isNotEmpty) {
      _selectedAdminId = widget.admins.first.id;
    }
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
    if (_selectedAdminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an admin'),
          backgroundColor: kAccentOrange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    widget.onAdd(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _passwordController.text,
      _selectedAdminId!,
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
            child: SingleChildScrollView(
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
                          gradient: AppGradients.cyan,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New User',
                              style: TextStyle(
                                color: kPrimaryTextColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'View-only access',
                              style: TextStyle(
                                color: kSecondaryTextColor,
                                fontSize: 13,
                              ),
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
                  
                  // Select admin
                  const Text(
                    'Assign to Admin',
                    style: TextStyle(
                      color: kSecondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: kGlassBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGlassBorder, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAdminId,
                        isExpanded: true,
                        dropdownColor: kCardBackground,
                        style: const TextStyle(color: kPrimaryTextColor),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kSecondaryTextColor),
                        items: widget.admins.map((admin) {
                          return DropdownMenuItem(
                            value: admin.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      admin.fullName.isNotEmpty ? admin.fullName[0].toUpperCase() : 'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(admin.fullName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedAdminId = value);
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
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
                          color: kAccentCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kAccentCyan.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.email_rounded, color: kAccentCyan, size: 18),
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
                                      color: kAccentCyan,
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
                          label: 'Create User',
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📋 USER DETAILS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _UserDetailsDialog extends StatelessWidget {
  final UserModel user;
  final String adminName;

  const _UserDetailsDialog({
    required this.user,
    required this.adminName,
  });

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
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
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
                          user.fullName,
                          style: const TextStyle(
                            color: kPrimaryTextColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RoleBadge(role: user.role),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: kSecondaryTextColor),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Permission notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kAccentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccentOrange.withOpacity(0.3), width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: kAccentOrange, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This user has view-only access to the dashboard.',
                        style: TextStyle(
                          color: kAccentOrange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Details
              _DetailItem(label: 'Email', value: user.email, icon: Icons.email_rounded),
              _DetailItem(label: 'First Name', value: user.firstName, icon: Icons.person_rounded),
              _DetailItem(label: 'Last Name', value: user.lastName, icon: Icons.person_outline_rounded),
              _DetailItem(label: 'Assigned Admin', value: adminName, icon: Icons.admin_panel_settings_rounded),
              _DetailItem(label: 'Role', value: user.role, icon: Icons.shield_rounded),
              _DetailItem(label: 'Status', value: user.status, icon: Icons.info_rounded),
              _DetailItem(label: 'User ID', value: user.id, icon: Icons.tag_rounded),
              if (user.createdAt != null)
                _DetailItem(
                  label: 'Created At',
                  value: '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}',
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
      padding: const EdgeInsets.only(bottom: 14),
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