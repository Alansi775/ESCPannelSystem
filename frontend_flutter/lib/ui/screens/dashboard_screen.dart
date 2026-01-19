import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/esc_provider.dart';
import '../../models/esc_models.dart';
import '../components/modern_components.dart';

/// Modern Dashboard Screen - لوحة التحكم الحديثة
class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Load data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ESCProvider>().loadAvailablePorts();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Consumer<ESCProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, theme),
                  const SizedBox(height: 32),

                  // Status Cards
                  _buildStatusCards(context, provider, theme),
                  const SizedBox(height: 32),

                  // Connection Info
                  if (provider.isConnected)
                    _buildConnectionInfo(context, provider, theme),

                  // Quick Actions
                  const SizedBox(height: 32),
                  _buildQuickActions(context, provider, theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESC Configuration',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Industrial Speed Controller System',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings,
                color: Color(0xFF007AFF),
                size: 24,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCards(
    BuildContext context,
    ESCProvider provider,
    ThemeData theme,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Connection Status
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.router,
                color: const Color(0xFF007AFF),
                size: 24,
              ),
              const SizedBox(height: 12),
              Text(
                'Connection',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.isConnected
                      ? const Color(0xFF34C759).withOpacity(0.1)
                      : const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  provider.isConnected ? 'متصل' : 'غير متصل',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: provider.isConnected
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Available Ports
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.usb,
                color: const Color(0xFF5AC8FA),
                size: 24,
              ),
              const SizedBox(height: 12),
              Text(
                'Available Ports',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${provider.availablePorts.length} منفذ',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5AC8FA),
                ),
              ),
            ],
          ),
        ),

        // Saved Profiles
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.bookmark,
                color: const Color(0xFF50E3C2),
                size: 24,
              ),
              const SizedBox(height: 12),
              Text(
                'Saved Profiles',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${provider.profiles.length} ملف',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF50E3C2),
                ),
              ),
            ],
          ),
        ),

        // System Status
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.check_circle,
                color: const Color(0xFF34C759),
                size: 24,
              ),
              const SizedBox(height: 12),
              Text(
                'System Status',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جاهز',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF34C759),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionInfo(
    BuildContext context,
    ESCProvider provider,
    ThemeData theme,
  ) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSectionHeader(
            title: 'Connection Information',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: theme.dividerColor,
          ),
          const SizedBox(height: 16),
          ModernParameterRow(
            label: 'Port Path',
            value: provider.currentStatus.portPath ?? 'N/A',
            unit: '',
          ),
          ModernParameterRow(
            label: 'Status',
            value: provider.isConnected ? 'Active' : 'Inactive',
            unit: '',
            valueColor: provider.isConnected
                ? const Color(0xFF34C759)
                : const Color(0xFFFF3B30),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    ESCProvider provider,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(
          title: 'Quick Actions',
          icon: Icons.lightning_bolt,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ModernGradientButton(
                label: 'Refresh Ports',
                onPressed: () => provider.loadAvailablePorts(),
                icon: Icons.refresh,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ModernGradientButton(
                label: 'Load Profiles',
                onPressed: () => provider.loadProfiles(),
                icon: Icons.cloud_download,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
