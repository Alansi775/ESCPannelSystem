/// Battery Configuration Screen
/// Input: Battery Cells, Auto-fill values from backend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/esc_models.dart';
import '../../state/esc_provider.dart';
import '../components/modern_components.dart';

class BatteryScreen extends StatefulWidget {
  const BatteryScreen({Key? key}) : super(key: key);

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  int _selectedCells = 4;
  String _selectedMode = 'middle';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<ESCProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
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
                          child: const Icon(Icons.battery_full, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Battery Configuration',
                              style: TextStyle(
                                color: AppColors.tungsten,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure battery cells and performance mode',
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

                    // Cell Count Selection
                    Text(
                      'Battery Cells (S)',
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
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 8 : 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: 8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final cells = index + 2;
                            final isSelected = _selectedCells == cells;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCells = cells;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [AppColors.electricBlue, AppColors.neonCyan],
                                        )
                                      : null,
                                  color: isSelected ? null : AppColors.charcoal.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${cells}S',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.black : AppColors.tungsten,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Mode Selection
                    Text(
                      'Performance Mode',
                      style: TextStyle(
                        color: AppColors.tungsten,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeCard(
                            icon: Icons.flash_on,
                            title: 'Light',
                            description: 'Racing\nMax Performance',
                            isSelected: _selectedMode == 'light',
                            onTap: () => setState(() => _selectedMode = 'light'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModeCard(
                            icon: Icons.tune,
                            title: 'Middle',
                            description: 'Balanced\nGood for Most',
                            isSelected: _selectedMode == 'middle',
                            onTap: () => setState(() => _selectedMode = 'middle'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModeCard(
                            icon: Icons.power,
                            title: 'High',
                            description: 'Heavy Lift\nHigh Torque',
                            isSelected: _selectedMode == 'high',
                            onTap: () => setState(() => _selectedMode = 'high'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Generate Config Button
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: 'Generate Configuration',
                        isLoading: provider.isLoading,
                        onPressed: provider.isLoading
                            ? () {}
                            : () async {
                                try {
                                  await provider.generateAutoConfig(
                                    _selectedCells,
                                    _selectedMode,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Configuration generated successfully'),
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

                    // Show generated config
                    if (provider.pendingConfig != null) ...[
                      const SizedBox(height: 40),
                      Text(
                        'Generated Configuration',
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
                            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildConfigItem('Max RPM', '${provider.pendingConfig!.maxRPM}'),
                              _buildConfigItem('Current Limit', '${provider.pendingConfig!.currentLimit}A'),
                              _buildConfigItem('PWM Freq', '${provider.pendingConfig!.pwmFreq} Hz'),
                              _buildConfigItem('Temp Limit', '${provider.pendingConfig!.tempLimit}°C'),
                              _buildConfigItem(
                                'Voltage Cutoff',
                                '${(provider.pendingConfig!.voltageCutoff / 100).toStringAsFixed(1)}V',
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.electricBlue, AppColors.neonCyan],
                )
              : null,
          color: isSelected ? null : AppColors.charcoal.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.black : AppColors.neonCyan,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.tungsten,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.black87 : AppColors.steel,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
