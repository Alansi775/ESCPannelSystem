/// Apply Configuration Screen
/// Button: APPLY TO ESC, Progress Indicator

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/esc_models.dart';
import '../../state/esc_provider.dart';
import '../components/modern_components.dart';

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({Key? key}) : super(key: key);

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  bool _isApplied = false;
  String? _profileName;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<ESCProvider>(
        builder: (context, provider, child) {
          final config = provider.pendingConfig ?? provider.currentConfig;

          if (!provider.isConnected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.alert.withOpacity(0.1),
                      border: Border.all(color: AppColors.alert, width: 2),
                    ),
                    child: const Icon(Icons.link_off, size: 48, color: AppColors.alert),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Not Connected',
                    style: TextStyle(
                      color: AppColors.tungsten,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please connect to ESC first',
                    style: TextStyle(
                      color: AppColors.steel,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          if (config == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.alert.withOpacity(0.1),
                      border: Border.all(color: AppColors.alert, width: 2),
                    ),
                    child: const Icon(Icons.settings_input_svideo, size: 48, color: AppColors.alert),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Configuration',
                    style: TextStyle(
                      color: AppColors.tungsten,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate a configuration first',
                    style: TextStyle(
                      color: AppColors.steel,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.electricBlue, AppColors.neonCyan],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flash_on, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Apply Configuration',
                              style: TextStyle(
                                color: AppColors.tungsten,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload settings to your ESC',
                              style: TextStyle(
                                color: AppColors.steel,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Current Configuration
                    Text(
                      'Configuration Summary',
                      style: TextStyle(
                        color: AppColors.tungsten,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassyCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildConfigItem('Max RPM', '${config.maxRPM}'),
                            _buildConfigItem('Current Limit', '${config.currentLimit}A'),
                            _buildConfigItem('PWM Frequency', '${config.pwmFreq} Hz'),
                            _buildConfigItem('Temperature Limit', '${config.tempLimit}°C'),
                            _buildConfigItem(
                              'Voltage Cutoff',
                              '${(config.voltageCutoff / 100).toStringAsFixed(1)}V',
                            ),
                            _buildConfigItem('Status', _isApplied ? '✓ Applied' : 'Pending'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: _isApplied ? 'Configuration Applied ✓' : 'Apply to ESC',
                        isLoading: provider.isLoading,
                        onPressed: provider.isLoading || _isApplied
                            ? () {}
                            : () async {
                                try {
                                  await provider.applyConfig(config);
                                  setState(() {
                                    _isApplied = true;
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Configuration applied successfully'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: AppColors.alert,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),

                    if (_isApplied) ...[
                      const SizedBox(height: 40),
                      Text(
                        'Save Profile',
                        style: TextStyle(
                          color: AppColors.tungsten,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassyCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(color: AppColors.tungsten),
                            decoration: InputDecoration(
                              hintText: 'Profile name (e.g., "Racing 4S")',
                              hintStyle: TextStyle(color: AppColors.steel),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.steel),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppColors.steel.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.neonCyan, width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: 'Save Profile',
                          isLoading: false,
                          onPressed: _nameController.text.isEmpty
                              ? () {}
                              : () async {
                                  try {
                                    await provider.saveProfile(
                                      _nameController.text,
                                      config,
                                    );
                                    setState(() {
                                      _profileName = _nameController.text;
                                    });
                                    _nameController.clear();

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Profile saved successfully'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: AppColors.alert,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                      if (_profileName != null) ...[
                        const SizedBox(height: 16),
                        GlassyCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.success.withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Profile Saved',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '"$_profileName"',
                                        style: TextStyle(
                                          color: AppColors.steel,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.steel,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.neonCyan,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
