import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'common.dart';
// import 'widgets.dart' as w; // Unused in this snippet, kept if needed elsewhere

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  
  // Visibility States for password fields
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  
  bool _isLoading = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final oldPwd = _oldController.text.trim();
    final newPwd = _newController.text.trim();

    setState(() => _isLoading = true);
    try {
      await ApiService.changeMyPassword(oldPassword: oldPwd, newPassword: newPwd);
      if (mounted) {
        // Show a centered, elegant success dialog instead of a bottom SnackBar
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            // Auto-close after 900ms
            Future.delayed(const Duration(milliseconds: 900), () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            });

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0,4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, color: kAccentGreen, size: 44),
                      const SizedBox(height: 12),
                      const Text(
                        'Password updated successfully',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: kPrimaryTextColor, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                        },
                        child: const Text('OK', style: TextStyle(color: kAccentGreen)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        _oldController.clear();
        _newController.clear();
        _confirmController.clear();
      }
    } catch (e) {
      if (mounted) {
        // Show a centered, dismissible dialog with a friendly English message.
        final raw = e?.toString() ?? '';
        String friendly;
        if (raw.contains('Current password is incorrect') || raw.toLowerCase().contains('current password') || raw.toLowerCase().contains('password is incorrect')) {
          friendly = 'Current password is incorrect';
        } else if (raw.contains('status: 403') || raw.toLowerCase().contains('forbidden')) {
          friendly = 'You are not authorized to change the password';
        } else {
          friendly = 'An error occurred, please try again later';
        }

        // showDialog is dismissible by tapping outside when barrierDismissible=true.
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            // Auto-close after 500ms
            Future.delayed(const Duration(milliseconds: 500), () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            });

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        friendly,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: kPrimaryTextColor),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                        },
                        child: const Text('OK', style: TextStyle(color: kAccentGreen)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reusable password field builder
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w500, 
            color: kSecondaryTextColor
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: kPrimaryTextColor),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: kSecondaryTextColor.withOpacity(0.5)),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: kSecondaryTextColor),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: kSecondaryTextColor,
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.1), // Light background for input
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // Rounded corners
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAccentGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAccentRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder helps us verify screen width if needed, 
    // but Center + ConstrainedBox is great for large screens.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600), // Max width for large screens
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Area
              const Text(
                'Settings', 
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: kPrimaryTextColor
                )
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your account security', 
                style: TextStyle(color: kSecondaryTextColor, fontSize: 16)
              ),
              const SizedBox(height: 40),

              // The Form Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05), // Slightly lighter background
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w600, 
                          color: kPrimaryTextColor
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Current Password
                      _buildPasswordField(
                        controller: _oldController,
                        label: 'Current password',
                        obscureText: _obscureOld,
                        onToggleVisibility: () => setState(() => _obscureOld = !_obscureOld),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
                      ),

                      // New Password
                      _buildPasswordField(
                        controller: _newController,
                        label: 'New password',
                        obscureText: _obscureNew,
                        onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter new password';
                          if (v.length < 8) return 'Password must be at least 8 characters';
                          return null;
                        },
                      ),

                      // Confirm Password
                      _buildPasswordField(
                        controller: _confirmController,
                        label: 'Confirm new password',
                        obscureText: _obscureConfirm,
                        onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirm new password';
                          if (v != _newController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAccentGreen, // Use your branding color
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                  : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: kSecondaryTextColor,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    _oldController.clear();
                                    _newController.clear();
                                    _confirmController.clear();
                                  },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}