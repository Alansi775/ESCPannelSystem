import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../ui/components/modern_components.dart';
import '../localization/translations.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onSignupSuccess;
  
  const SignUpScreen({Key? key, this.onSignupSuccess}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _showVerificationMessage = false;
  String? _signupEmail;
  String _language = 'tr';

  String _t(String key) => Translations.t(_language, key);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await AuthenticationService.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        language: _language,
      );
      if (!mounted) return;
      if (result['success']) {
        setState(() {
          _showVerificationMessage = true;
          _signupEmail = _emailController.text.trim();
          _isLoading = false;
        });
      } else {
        String errorMessage = result['error'] ?? _t('signup_error');
        if (errorMessage.contains('already exists')) errorMessage = _t('signup_email_exists');
        if (errorMessage.contains('weak')) errorMessage = _t('signup_weak_password');
        
        _showErrorDialog(errorMessage);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(_t('signup_network_error'));
    }
  }

  void _showErrorDialog(String message) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text(_t('signup_error'), style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: AppColors.steel)),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('OK', style: TextStyle(color: AppColors.electricBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showVerificationMessage) {
      return _buildSuccessView();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CinematicBackground(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              children: [
                // --- Left Side: Welcome Visual ---
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withOpacity(0.3)),
                        ),
                        child: const Text(
                          "NEW USER REGISTRATION",
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _t('signup_title'),
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Join the ecosystem.\nConfigure, monitor, and deploy.\nIndustrial grade precision.",
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.steel,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Right Side: Registration Form ---
                Expanded(
                  flex: 4,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: HolographicCard(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Create Account",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    LanguageSelector(
                                      currentLang: _language,
                                      onSelect: (val) => setState(() => _language = val),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                CyberInput(
                                  controller: _nameController,
                                  label: _t('signup_name'),
                                  icon: Icons.person_outline,
                                  validator: (v) => (v?.isEmpty ?? true) ? _t('signup_name_required') : null,
                                ),
                                const SizedBox(height: 20),
                                CyberInput(
                                  controller: _emailController,
                                  label: _t('signup_email'),
                                  icon: Icons.alternate_email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return _t('signup_email_required');
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) return _t('signup_invalid_email');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                CyberInput(
                                  controller: _passwordController,
                                  label: _t('signup_password'),
                                  icon: Icons.lock_outline,
                                  obscureText: true,
                                  validator: (v) {
                                    if (v?.isEmpty ?? true) return _t('signup_password_required');
                                    if ((v?.length ?? 0) < 6) return _t('signup_password_min');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 32),

                                HyperButton(
                                  label: _t('signup_button'),
                                  onPressed: _handleSignup,
                                  isLoading: _isLoading,
                                ),
                                const SizedBox(height: 32),

                                Center(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: RichText(
                                      text: TextSpan(
                                        text: '${_t('signup_already_member')} ',
                                        style: const TextStyle(color: AppColors.steel),
                                        children: [
                                          TextSpan(
                                            text: _t('signup_login'),
                                            style: const TextStyle(
                                              color: AppColors.electricBlue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CinematicBackground(
        child: Center(
          child: HolographicCard(
            child: Container(
              width: 450,
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.success.withOpacity(0.2), blurRadius: 40)
                      ],
                    ),
                    child: const Icon(Icons.check, color: AppColors.success, size: 40),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _t('signup_success'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(_t('signup_check_email'), style: const TextStyle(color: AppColors.steel)),
                        const SizedBox(height: 8),
                        Text(
                          _signupEmail ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  HyperButton(
                    label: _t('signup_back'),
                    onPressed: () {
                      Navigator.pop(context); // Go back to login
                    },
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