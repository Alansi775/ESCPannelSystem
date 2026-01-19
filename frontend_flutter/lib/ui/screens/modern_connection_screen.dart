import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/esc_provider.dart';
import '../../models/esc_models.dart';
import '../components/modern_components.dart';

/// Modern Connection Screen - شاشة الاتصال الحديثة
class ModernConnectionScreen extends StatefulWidget {
  const ModernConnectionScreen({Key? key}) : super(key: key);

  @override
  State<ModernConnectionScreen> createState() => _ModernConnectionScreenState();
}

class _ModernConnectionScreenState extends State<ModernConnectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

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

    return FadeTransition(
      opacity: CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)),
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

                // Connection Status
                _buildConnectionStatus(context, theme),
                const SizedBox(height: 32),

                // Available Ports
                _buildPortsList(context, theme),
              ],
            ),
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
          'Connection',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select and connect to your ESC device',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(BuildContext context, ThemeData theme) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        return ModernCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connection Status',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: provider.isConnected
                          ? const Color(0xFF34C759).withOpacity(0.1)
                          : const Color(0xFFFF3B30).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.isConnected ? '✓ متصل' : '○ غير متصل',
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
              const SizedBox(height: 16),
              if (provider.isConnected)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModernParameterRow(
                      label: 'Connected Port',
                      value: provider.currentStatus.portPath?.split('/').last ?? 'N/A',
                      unit: '',
                    ),
                    const SizedBox(height: 16),
                    ModernGradientButton(
                      label: 'Disconnect',
                      onPressed: () => provider.disconnectESC(),
                      isDangerous: true,
                      icon: Icons.close,
                    ),
                  ],
                )
              else
                Text(
                  'No device connected. Select a port below to connect.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortsList(BuildContext context, ThemeData theme) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingPorts) {
          return ModernLoadingState(message: 'جاري البحث عن المنافذ...');
        }

        if (provider.availablePorts.isEmpty) {
          return ModernEmptyState(
            title: 'No Ports Found',
            subtitle: 'Connect an ESC device via USB',
            icon: Icons.usb_off,
            onAction: () => provider.loadAvailablePorts(),
            actionLabel: 'Refresh Ports',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernSectionHeader(
              title: 'Available Ports',
              subtitle: '${provider.availablePorts.length} منفذ متاح',
              icon: Icons.router,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.availablePorts.length,
              itemBuilder: (context, index) {
                final port = provider.availablePorts[index];
                final isCurrentPort = provider.isConnected &&
                    provider.currentStatus.portPath == port.path;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ModernCard(
                    isSelected: isCurrentPort,
                    onTap: () async {
                      if (!isCurrentPort) {
                        try {
                          await provider.connectToESC(port.path);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ في الاتصال: $e'),
                              backgroundColor: const Color(0xFFFF3B30),
                            ),
                          );
                        }
                      }
                    },
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.devices,
                            color: Color(0xFF007AFF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Port Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                port.path.split('/').last,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                port.manufacturer ?? 'Unknown Manufacturer',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.6),
                                ),
                              ),
                              if (port.serialNumber != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'SN: ${port.serialNumber}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Status indicator
                        if (isCurrentPort)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF34C759),
                              size: 20,
                            ),
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.3),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
