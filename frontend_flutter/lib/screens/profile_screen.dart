/// Profile Screen
/// User account information and settings

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../localization/translations.dart';
import '../ui/components/modern_components.dart';
import '../state/esc_provider.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _t(String key, String lang) => Translations.t(lang, key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        
        return CinematicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.charcoal.withOpacity(0.6),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                        ),
                      ),
                      Text(
                        'Profile',
                        style: const TextStyle(
                          color: AppColors.tungsten,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      LanguageSelector(
                        currentLang: lang,
                        onSelect: (newLang) {
                          provider.setLanguage(newLang.toUpperCase());
                        },
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Avatar
                            Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.electricBlue.withOpacity(0.6),
                                      AppColors.neonCyan.withOpacity(0.3),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.electricBlue.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    ((widget.user['name'] ?? '')[0] ?? 'U').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // User Info Card
                            GlassyCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoItem(
                                    icon: Icons.person_outline,
                                    label: _t('profile_name', lang),
                                    value: widget.user['name'] ?? 'N/A',
                                  ),
                                  const Divider(height: 24, color: Colors.white10),
                                  _buildInfoItem(
                                    icon: Icons.email_outlined,
                                    label: _t('profile_email', lang),
                                    value: widget.user['email'] ?? 'N/A',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Security Section
                            Text(
                              _t('profile_security', lang),
                              style: const TextStyle(
                                color: AppColors.tungsten,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Security Buttons - Responsive Layout
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 700;
                                
                                if (isWide) {
                                  // Horizontal layout for laptop screens
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: GradientButton(
                                          label: _t('profile_change_password', lang),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChangePasswordScreen(
                                                  userId: widget.user['id'],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ForgotPasswordScreen(
                                                  email: widget.user['email'],
                                                ),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: const BorderSide(color: AppColors.electricBlue, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            _t('profile_forgot_password', lang),
                                            style: const TextStyle(
                                              color: AppColors.electricBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => _buildLogoutDialog(lang),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.alert,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            _t('profile_logout', lang),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  // Vertical layout for mobile screens
                                  return Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: GradientButton(
                                          label: _t('profile_change_password', lang),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChangePasswordScreen(
                                                  userId: widget.user['id'],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ForgotPasswordScreen(
                                                  email: widget.user['email'],
                                                ),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: const BorderSide(color: AppColors.electricBlue, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            _t('profile_forgot_password', lang),
                                            style: const TextStyle(
                                              color: AppColors.electricBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => _buildLogoutDialog(lang),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.alert,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            _t('profile_logout', lang),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.electricBlue, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.steel,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.tungsten,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutDialog(String lang) {
    return Dialog(
      backgroundColor: AppColors.charcoal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.alert.withOpacity(0.1),
                  border: Border.all(color: AppColors.alert, width: 1.5),
                ),
                child: const Icon(Icons.logout, color: AppColors.alert, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                _t('profile_logout_confirm', lang),
                style: const TextStyle(
                  color: AppColors.tungsten,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t('profile_logout_message', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.steel,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: AppColors.steel, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _t('profile_logout_no', lang),
                        style: const TextStyle(
                          color: AppColors.steel,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await SessionManager.clearUserSession();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.alert,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _t('profile_logout_yes', lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Change Password Screen
class ChangePasswordScreen extends StatefulWidget {
  final int userId;

  const ChangePasswordScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _language = 'en';

  String _t(String key) => Translations.t(_language, key);
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar(_t('change_password_mismatch'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthenticationService.changePassword(
        userId: widget.userId,
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (response['success']) {
        _showSnackBar(_t('change_password_success'), isError: false);
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      } else {
        _showSnackBar(response['error'] ?? _t('change_password_error'), isError: true);
      }
    } catch (e) {
      _showSnackBar(_t('change_password_network_error'), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.alert : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('change_password_title')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CinematicBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.electricBlue.withOpacity(0.1),
                  border: Border.all(color: AppColors.electricBlue, width: 2),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.electricBlue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              // Old Password
              _buildPasswordField(
                controller: _oldPasswordController,
                label: _t('change_password_old'),
                isVisible: _showOldPassword,
                onToggle: () => setState(() => _showOldPassword = !_showOldPassword),
              ),
              const SizedBox(height: 16),
              // New Password
              _buildPasswordField(
                controller: _newPasswordController,
                label: _t('change_password_new'),
                isVisible: _showNewPassword,
                onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
              ),
              const SizedBox(height: 16),
              // Confirm Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: _t('change_password_confirm'),
                isVisible: _showConfirmPassword,
                onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: _t('change_password_button'),
                  isLoading: _isLoading,
                  onPressed: _changePassword,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return GlassyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.steel,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: !isVisible,
            style: const TextStyle(color: AppColors.tungsten),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '••••••••',
              hintStyle: const TextStyle(color: AppColors.steel),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.steel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Forgot Password Screen
class ForgotPasswordScreen extends StatefulWidget {
  final String email;

  const ForgotPasswordScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String _language = 'en';

  String _t(String key) => Translations.t(_language, key);

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar(_t('forgot_password_email_required'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthenticationService.forgotPassword(
        email: _emailController.text,
      );

      if (response['success']) {
        setState(() => _emailSent = true);
        _showSnackBar(_t('forgot_password_sent'), isError: false);
      } else {
        _showSnackBar(response['error'] ?? _t('forgot_password_error'), isError: true);
      }
    } catch (e) {
      _showSnackBar(_t('forgot_password_network_error'), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.alert : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t('forgot_password_title')),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: CinematicBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.1),
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _t('forgot_password_success'),
                    style: const TextStyle(
                      color: AppColors.tungsten,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('forgot_password_check_email'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.steel,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    label: _t('forgot_password_ok'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('forgot_password_title')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CinematicBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.electricBlue.withOpacity(0.1),
                  border: Border.all(color: AppColors.electricBlue, width: 2),
                ),
                child: const Icon(
                  Icons.lock_open_outlined,
                  color: AppColors.electricBlue,
                  size: 50,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _t('forgot_password_title'),
                style: const TextStyle(
                  color: AppColors.tungsten,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _t('forgot_password_button'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.steel,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              // Email Field
              GlassyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('forgot_password_email'),
                      style: const TextStyle(
                        color: AppColors.steel,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.tungsten),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'your@email.com',
                        hintStyle: const TextStyle(color: AppColors.steel),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.electricBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: _t('forgot_password_button'),
                  isLoading: _isLoading,
                  onPressed: _sendResetLink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
