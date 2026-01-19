import 'package:flutter/material.dart';
import '../components/modern_components.dart';

/// Advanced Modern Apply Screen - شاشة التطبيق المتقدمة
class ModernApplyScreen extends StatefulWidget {
  const ModernApplyScreen({Key? key}) : super(key: key);

  @override
  State<ModernApplyScreen> createState() => _ModernApplyScreenState();
}

class _ModernApplyScreenState extends State<ModernApplyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isApplying = false;
  bool _isSuccess = false;
  String _profileName = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, theme),
              const SizedBox(height: 32),

              if (!_isSuccess) ...[
                // Configuration Preview
                _buildConfigPreview(context, theme),
                const SizedBox(height: 32),

                // Apply Section
                _buildApplySection(context, theme),
              ] else
                // Success State
                _buildSuccessState(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Apply Configuration',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Review and apply settings to your ESC device',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigPreview(BuildContext context, ThemeData theme) {
    // Mock configuration data
    final config = {
      'Max RPM': '48000',
      'Current Limit': '120',
      'PWM Frequency': '16',
      'Temperature Limit': '80',
      'Voltage Cutoff': '3.0',
    };

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSectionHeader(
            title: 'Configuration Preview',
            subtitle: 'All settings before applying',
            icon: Icons.preview,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 16),
          ...config.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ModernParameterRow(
                label: e.key,
                value: e.value,
                unit: _getUnit(e.key),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildApplySection(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernSectionHeader(
                title: 'Save Profile',
                subtitle: 'Optionally save these settings',
                icon: Icons.bookmark,
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  setState(() => _profileName = value);
                },
                decoration: InputDecoration(
                  hintText: 'Profile name (e.g., Racing Profile)',
                  prefixIcon: const Icon(Icons.label),
                  enabled: !_isApplying,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ModernGradientButton(
          label: _isApplying ? 'Applying...' : 'Apply to ESC',
          onPressed: _isApplying ? () {} : () => _applyConfiguration(),
          isLoading: _isApplying,
          icon: Icons.send,
        ),
        const SizedBox(height: 16),
        Text(
          'The ESC will restart after applying the configuration',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFF34C759),
            size: 80,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Configuration Applied!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF34C759),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your ESC has been successfully configured and restarted.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (_profileName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Saved as: $_profileName',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
        ],
        const SizedBox(height: 32),
        ModernGradientButton(
          label: 'Done',
          onPressed: () => setState(() => _isSuccess = false),
          icon: Icons.check,
        ),
      ],
    );
  }

  void _applyConfiguration() async {
    setState(() => _isApplying = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isApplying = false;
      _isSuccess = true;
    });
  }

  String _getUnit(String key) {
    switch (key) {
      case 'Max RPM':
        return 'RPM';
      case 'Current Limit':
        return 'A';
      case 'PWM Frequency':
        return 'kHz';
      case 'Temperature Limit':
        return '°C';
      case 'Voltage Cutoff':
        return 'V/S';
      default:
        return '';
    }
  }
}
