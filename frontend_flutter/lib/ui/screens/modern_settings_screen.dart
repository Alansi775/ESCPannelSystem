import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/esc_provider.dart';
import '../components/modern_components.dart';

/// Modern Settings Screen - شاشة الإعدادات الحديثة
class ModernSettingsScreen extends StatefulWidget {
  const ModernSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ModernSettingsScreen> createState() => _ModernSettingsScreenState();
}

class _ModernSettingsScreenState extends State<ModernSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedCells = 4;
  String _selectedMode = 'middle';

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

              // Battery Configuration
              _buildBatteryConfiguration(context, theme),
              const SizedBox(height: 32),

              // Operating Mode
              _buildOperatingMode(context, theme),
              const SizedBox(height: 32),

              // Generate Button
              _buildGenerateButton(context, theme),
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
          'Configuration',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Auto-generate ESC settings based on your needs',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryConfiguration(BuildContext context, ThemeData theme) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSectionHeader(
            title: 'Battery Configuration',
            subtitle: 'Select the number of cells (S)',
            icon: Icons.battery_std,
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(8, (index) {
              final cells = index + 2; // 2S to 9S
              final isSelected = _selectedCells == cells;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCells = cells);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : theme.brightness == Brightness.dark
                            ? const Color(0xFF1A1F3A)
                            : const Color(0xFFF2F2F7),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$cells',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: isSelected ? Colors.white : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? Colors.white.withOpacity(0.7)
                                : theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatingMode(BuildContext context, ThemeData theme) {
    final modes = [
      {
        'id': 'light',
        'name': 'Light',
        'icon': Icons.flash_on,
        'description': 'High-speed racing',
        'color': Color(0xFFFF9500),
      },
      {
        'id': 'middle',
        'name': 'Balanced',
        'icon': Icons.scale,
        'description': 'Balanced performance',
        'color': Color(0xFF007AFF),
      },
      {
        'id': 'high',
        'name': 'Heavy Duty',
        'icon': Icons.directions_boat,
        'description': 'Maximum power',
        'color': Color(0xFF34C759),
      },
    ];

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSectionHeader(
            title: 'Operating Mode',
            subtitle: 'Choose the configuration profile',
            icon: Icons.tune,
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(modes.length, (index) {
              final mode = modes[index];
              final isSelected = _selectedMode == mode['id'];

              return Padding(
                padding: EdgeInsets.only(bottom: index < modes.length - 1 ? 12 : 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedMode = mode['id'] as String);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (mode['color'] as Color).withOpacity(0.1)
                          : theme.brightness == Brightness.dark
                              ? const Color(0xFF242B48)
                              : const Color(0xFFF2F2F7),
                      border: Border.all(
                        color: isSelected
                            ? (mode['color'] as Color).withOpacity(0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (mode['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            mode['icon'] as IconData,
                            color: mode['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode['name'] as String,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: mode['color'] as Color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mode['description'] as String,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Check indicator
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: mode['color'] as Color,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(BuildContext context, ThemeData theme) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            ModernGradientButton(
              label: 'Generate Configuration',
              onPressed: () async {
                try {
                  await provider.generateAutoConfig(
                    cells: _selectedCells,
                    mode: _selectedMode,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✓ تم إنشاء الإعدادات بنجاح'),
                      backgroundColor: const Color(0xFF34C759),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: const Color(0xFFFF3B30),
                    ),
                  );
                }
              },
              icon: Icons.lightning_bolt,
            ),
            const SizedBox(height: 16),
            Text(
              'Configuration will be optimized for ${_selectedCells}S battery in $_selectedMode mode',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}
