import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../../state/esc_provider.dart';
import '../components/modern_components.dart';
import '../../screens/profile_screen.dart';
import '../../localization/translations.dart';

class WizardMainScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const WizardMainScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<WizardMainScreen> createState() => _WizardMainScreenState();
}

class _WizardMainScreenState extends State<WizardMainScreen> {
  int _currentStep = 0;

  final List<WizardStep> _steps = [
    WizardStep(title: 'Connect', icon: Icons.usb),
    WizardStep(title: 'Battery', icon: Icons.battery_full),
    WizardStep(title: 'Sensor', icon: Icons.sensors),
    WizardStep(title: 'Motor', icon: Icons.bolt),
    WizardStep(title: 'Control', icon: Icons.tune),
    WizardStep(title: 'Review', icon: Icons.checklist),
    WizardStep(title: 'Apply', icon: Icons.flash_on),
  ];

  void _goToStep(int step) {
    if (step < _currentStep) {
      setState(() => _currentStep = step);
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CinematicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.electricBlue, AppColors.neonCyan],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.settings_input_composite, color: Colors.black, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'ESC Configurator',
                                style: TextStyle(
                                  color: AppColors.tungsten,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Professional Motor Controller Setup',
                            style: TextStyle(
                              color: AppColors.steel,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          LanguageSelector(
                            currentLang: context.watch<ESCProvider>().currentLanguage.toLowerCase(),
                            onSelect: (lang) {
                              context.read<ESCProvider>().setLanguage(lang.toUpperCase());
                            },
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    user: widget.userData ?? {
                                      'id': 1,
                                      'name': 'User',
                                      'email': 'user@example.com',
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.electricBlue, AppColors.neonCyan],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.electricBlue.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, color: Colors.black, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildStepIndicator(),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCurrentStep(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  // Left Navigation Button (Back)
                  Positioned(
                    left: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _currentStep > 0 ? 1.0 : 0.3,
                        duration: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          onTap: _currentStep > 0 ? _prevStep : null,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _currentStep > 0
                                  ? const LinearGradient(
                                      colors: [AppColors.electricBlue, AppColors.neonCyan],
                                    )
                                  : LinearGradient(
                                      colors: [AppColors.charcoal, AppColors.charcoal.withOpacity(0.7)],
                                    ),
                              boxShadow: _currentStep > 0
                                  ? [
                                      BoxShadow(
                                        color: AppColors.electricBlue.withOpacity(0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: _currentStep > 0 ? Colors.black : AppColors.steel,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right Navigation Button (Next)
                  Positioned(
                    right: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _currentStep < _steps.length - 1 ? 1.0 : 0.3,
                        duration: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          onTap: _currentStep < _steps.length - 1 ? _nextStep : null,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _currentStep < _steps.length - 1
                                  ? const LinearGradient(
                                      colors: [AppColors.electricBlue, AppColors.neonCyan],
                                    )
                                  : LinearGradient(
                                      colors: [AppColors.charcoal, AppColors.charcoal.withOpacity(0.7)],
                                    ),
                              boxShadow: _currentStep < _steps.length - 1
                                  ? [
                                      BoxShadow(
                                        color: AppColors.electricBlue.withOpacity(0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: _currentStep < _steps.length - 1 ? Colors.black : AppColors.steel,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            _steps.length,
            (index) => GestureDetector(
              onTap: () => _goToStep(index),
              child: SizedBox(
                width: 100,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: index < _currentStep ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: index == _currentStep
                            ? AppColors.electricBlue.withOpacity(0.2)
                            : index < _currentStep
                                ? AppColors.neonCyan.withOpacity(0.15)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == _currentStep
                              ? AppColors.electricBlue
                              : index < _currentStep
                                  ? AppColors.neonCyan
                                  : AppColors.steel.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _steps[index].icon,
                            size: 20,
                            color: index == _currentStep
                                ? AppColors.neonCyan
                                : index < _currentStep
                                    ? AppColors.success
                                    : AppColors.steel,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _steps[index].title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: index == _currentStep ? FontWeight.w600 : FontWeight.w400,
                              color: index == _currentStep ? AppColors.tungsten : AppColors.steel,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return const WizardConnectStep();
      case 1:
        return const WizardBatteryStep();
      case 2:
        return const WizardSensorStep();
      case 3:
        return const WizardMotorStep();
      case 4:
        return const WizardControlStep();
      case 5:
        return const WizardReviewStep();
      case 6:
        return const WizardApplyStep();
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

}

class WizardStep {
  final String title;
  final IconData icon;

  WizardStep({required this.title, required this.icon});
}

class WizardConnectStep extends StatefulWidget {
  const WizardConnectStep({Key? key}) : super(key: key);

  @override
  State<WizardConnectStep> createState() => _WizardConnectStepState();
}

class _WizardConnectStepState extends State<WizardConnectStep> {
  String? _selectedPort;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ESCProvider>().loadAvailablePorts());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 700;
                    
                    return isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildStatusCard(provider, lang),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 3,
                                child: _buildPortsCard(provider, lang),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildStatusCard(provider, lang),
                              const SizedBox(height: 24),
                              _buildPortsCard(provider, lang),
                            ],
                            );
                    },
                ),
                ),
            ),
            ),
        );
        },
    );
  }

  Widget _buildStatusCard(ESCProvider provider, String lang) {
    return GlassyCard(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Translations.t(lang, 'system_status'), style: TextStyle(color: AppColors.steel, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 32),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.isConnected ? AppColors.success.withOpacity(0.1) : AppColors.alert.withOpacity(0.1),
                border: Border.all(
                  color: provider.isConnected ? AppColors.success : AppColors.alert,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (provider.isConnected ? AppColors.success : AppColors.alert).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: Icon(
                provider.isConnected ? Icons.link : Icons.link_off,
                size: 48,
                color: provider.isConnected ? AppColors.success : AppColors.alert,
              ),
            ),
            const SizedBox(height: 32),
            StatusIndicator(
              isConnected: provider.isConnected,
              label: provider.isConnected ? Translations.t(lang, 'connected') : Translations.t(lang, 'offline'),
            ),
            if (provider.isConnected) ...[
              const SizedBox(height: 24),
              Text(
                "${Translations.t(lang, 'port_label')} ${provider.connectedPort}",
                style: const TextStyle(color: AppColors.tungsten, fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortsCard(ESCProvider provider, String lang) {
    return GlassyCard(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Translations.t(lang, 'available_interfaces'), style: const TextStyle(color: AppColors.tungsten, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.neonCyan, size: 20),
                  onPressed: () => provider.loadAvailablePorts(),
                  tooltip: Translations.t(lang, 'refresh'),
                )
              ],
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            if (provider.isLoading)
              LoadingIndicator(message: Translations.t(lang, 'scanning'))
            else if (provider.availablePorts.isEmpty)
              ErrorMessageWidget(message: Translations.t(lang, 'no_devices'))
            else
              Column(
                children: provider.availablePorts.map((port) {
                  final isSelected = _selectedPort == port.path;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPort = port.path),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.electricBlue.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.neonCyan : Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.usb, color: isSelected ? AppColors.neonCyan : AppColors.steel),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(port.path, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                Text(port.description, style: TextStyle(color: AppColors.steel, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.neonCyan, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: provider.isConnected ? Translations.t(lang, 'connected_check') : Translations.t(lang, 'establish_connection'),
                isLoading: provider.isLoading,
                onPressed: _selectedPort == null || provider.isLoading ? () {} : () => provider.connectToESC(_selectedPort!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WizardBatteryStep extends StatefulWidget {
  const WizardBatteryStep({Key? key}) : super(key: key);

  @override
  State<WizardBatteryStep> createState() => _WizardBatteryStepState();
}

class _WizardBatteryStepState extends State<WizardBatteryStep> {
  late int _selectedCells;

  @override
  void initState() {
    super.initState();
    _selectedCells = context.read<ESCProvider>().wizardBatteryCells;
  }

  bool get _isIndustrial => _selectedCells >= 13;
  Color get _categoryColor => _isIndustrial ? AppColors.alert : AppColors.success;

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        final categoryLabel = _isIndustrial
          ? Translations.t(lang, 'battery_category_industrial')
          : Translations.t(lang, 'battery_category_standard');

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Translations.t(lang, 'battery_cells_label'),
                          style: TextStyle(
                            color: AppColors.tungsten,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _categoryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _categoryColor, width: 1),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(
                              color: _categoryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 12),
                Text(
                  '${_selectedCells}S',
                  style: TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isIndustrial)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.alert.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.alert.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.alert, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            Translations.t(
                              context.read<ESCProvider>().currentLanguage.toLowerCase(),
                              'battery_high_voltage_warning',
                            ),
                            style: TextStyle(
                              color: AppColors.alert,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                GlassyCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Translations.t(
                            context.read<ESCProvider>().currentLanguage.toLowerCase(),
                            'battery_standard_range',
                          ),
                          style: TextStyle(
                            color: AppColors.steel,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 12 : 6,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: 11,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final cells = index + 2;
                            final isSelected = _selectedCells == cells;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedCells = cells);
                                context.read<ESCProvider>().setWizardBatteryCells(cells);
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
                                      fontSize: 16,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GlassyCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Translations.t(
                            context.read<ESCProvider>().currentLanguage.toLowerCase(),
                            'battery_industrial_range',
                          ),
                          style: TextStyle(
                            color: AppColors.steel,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 12 : 6,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: 18,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final cells = index + 13;
                            final isSelected = _selectedCells == cells;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedCells = cells);
                                context.read<ESCProvider>().setWizardBatteryCells(cells);
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
                                    color: isSelected ? AppColors.neonCyan : AppColors.alert.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${cells}S',
                                    style: TextStyle(
                                      fontSize: 16,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      );
      },
    );
  }
}

class WizardMotorStep extends StatefulWidget {
  const WizardMotorStep({Key? key}) : super(key: key);

  @override
  State<WizardMotorStep> createState() => _WizardMotorStepState();
}

class _WizardMotorStepState extends State<WizardMotorStep> {
  late String _motorType;
  late int _polePairs;
  late int _kvRating;
  late int _maxCurrent;
  late int _maxRPM;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ESCProvider>();
    _motorType = provider.wizardMotorType;
    _polePairs = provider.wizardPolePairs;
    _kvRating = provider.wizardKV;
    _maxCurrent = provider.wizardMaxCurrent;
    _maxRPM = provider.wizardMaxRPM;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.t(lang, 'motor_configuration'),
                      style: TextStyle(color: AppColors.tungsten, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    GlassyCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMotorField(
                              Translations.t(lang, 'motor_type'),
                              ['BLDC', 'PMSM'],
                              _motorType,
                              (val) {
                                setState(() => _motorType = val);
                                context.read<ESCProvider>().setWizardMotorType(val);
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildNumberField(
                              Translations.t(lang, 'motor_pole_pairs'),
                              _polePairs,
                              (val) {
                                setState(() => _polePairs = val);
                                context.read<ESCProvider>().setWizardPolePairs(val);
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildNumberField(
                              Translations.t(lang, 'motor_kv_rating'),
                              _kvRating,
                              (val) {
                                setState(() => _kvRating = val);
                                context.read<ESCProvider>().setWizardKV(val);
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildNumberField(
                              Translations.t(lang, 'motor_max_current'),
                              _maxCurrent,
                              (val) {
                                setState(() => _maxCurrent = val);
                                context.read<ESCProvider>().setWizardMaxCurrent(val);
                              },
                            ),
                            const SizedBox(height: 20),
                            if (provider.wizardSensorMode != 'Sensorless')
                              Column(
                                children: [
                                  _buildNumberField(
                                    Translations.t(lang, 'motor_max_rpm'),
                                    _maxRPM,
                                    (val) {
                                      setState(() => _maxRPM = val);
                                      context.read<ESCProvider>().setWizardMaxRPM(val);
                                    },
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
          ),
        );
      },
    );
  }

  Widget _buildMotorField(String label, List<String> options, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.steel, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = opt == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.electricBlue.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? AppColors.neonCyan : AppColors.steel,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.steel, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.steel.withOpacity(0.2)),
                ),
                child: Text(
                  value.toString(),
                  style: const TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.remove, color: AppColors.steel),
              onPressed: () => onChanged(value - 1),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.neonCyan),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class WizardSensorStep extends StatefulWidget {
  const WizardSensorStep({Key? key}) : super(key: key);

  @override
  State<WizardSensorStep> createState() => _WizardSensorStepState();
}

class _WizardSensorStepState extends State<WizardSensorStep> {
  late String _sensorMode;

  @override
  void initState() {
    super.initState();
    _sensorMode = context.read<ESCProvider>().wizardSensorMode;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.t(lang, 'sensor_configuration'),
                      style: TextStyle(color: AppColors.tungsten, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    GlassyCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            'Sensorless',
                            'Hall',
                            'Encoder',
                            'Resolver'
                          ].map((mode) {
                            final isSelected = mode == _sensorMode;
                            final translationKey = 'sensor_${mode.toLowerCase()}';
                            final displayText = Translations.t(lang, translationKey);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _sensorMode = mode);
                                  context.read<ESCProvider>().setWizardSensorMode(mode);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(colors: [AppColors.electricBlue, AppColors.neonCyan])
                                        : null,
                                    color: isSelected ? null : AppColors.charcoal.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.sensors,
                                        color: isSelected ? Colors.black : AppColors.steel,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        displayText,
                                        style: TextStyle(
                                          color: isSelected ? Colors.black : AppColors.tungsten,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WizardControlStep extends StatefulWidget {
  const WizardControlStep({Key? key}) : super(key: key);

  @override
  State<WizardControlStep> createState() => _WizardControlStepState();
}

class _WizardControlStepState extends State<WizardControlStep> {
  late String _controlMode;
  late int _pwmFreq;
  late int _tempLimit;
  late int _overcurrentLimit;
  late bool _brakeEnabled;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ESCProvider>();
    _controlMode = provider.wizardControlMode;
    _pwmFreq = provider.wizardPWMFreq;
    _tempLimit = provider.wizardMaxTemp;
    _overcurrentLimit = provider.wizardOvercurrent;
    _brakeEnabled = provider.wizardBrakeEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.t(lang, 'control_protection'),
                      style: TextStyle(color: AppColors.tungsten, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    GlassyCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildField(
                              Translations.t(lang, 'control_mode'),
                              ['Throttle', 'Cruise', 'Governor'],
                              _controlMode,
                              (val) {
                                setState(() => _controlMode = val);
                                context.read<ESCProvider>().setWizardControlMode(val);
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildBrakeToggle(
                              Translations.t(lang, 'enable_brake'),
                              _brakeEnabled,
                              (val) {
                                setState(() => _brakeEnabled = val);
                                context.read<ESCProvider>().setWizardBrakeEnabled(val);
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildSlider(
                              Translations.t(lang, 'pwm_frequency'),
                              _pwmFreq,
                              1,
                              32,
                              (val) {
                                setState(() => _pwmFreq = val.toInt());
                                context.read<ESCProvider>().setWizardPWMFreq(val.toInt());
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildSlider(
                              Translations.t(lang, 'temperature_limit'),
                              _tempLimit,
                              40,
                              100,
                              (val) {
                                setState(() => _tempLimit = val.toInt());
                                context.read<ESCProvider>().setWizardMaxTemp(val.toInt());
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildSlider(
                              Translations.t(lang, 'overcurrent_limit'),
                              _overcurrentLimit,
                              50,
                              300,
                              (val) {
                                setState(() => _overcurrentLimit = val.toInt());
                                context.read<ESCProvider>().setWizardOvercurrent(val.toInt());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrakeToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.steel, fontSize: 12, fontWeight: FontWeight.w500)),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              color: value ? AppColors.neonCyan.withOpacity(0.3) : AppColors.charcoal.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: value ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2)),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? AppColors.neonCyan : AppColors.steel,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, List<String> options, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.steel, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = opt == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.electricBlue.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.neonCyan : AppColors.steel.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? AppColors.neonCyan : AppColors.steel,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, int value, int min, int max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.steel, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.steel.withOpacity(0.2)),
                ),
                child: Text(
                  value.toString(),
                  style: const TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.w600, fontFamily: 'monospace', fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.remove, color: AppColors.steel),
              onPressed: value > min ? () => onChanged((value - 1).toDouble()) : null,
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.neonCyan),
              onPressed: value < max ? () => onChanged((value + 1).toDouble()) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class WizardReviewStep extends StatelessWidget {
  const WizardReviewStep({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Consumer<ESCProvider>(
              builder: (context, provider, _) {
                final voltage = provider.wizardBatteryCells * 3.7;
                final isIndustrial = provider.wizardBatteryCells >= 13;
                final lang = provider.currentLanguage.toLowerCase();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.t(lang, 'configuration_review'),
                      style: TextStyle(color: AppColors.tungsten, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    GlassyCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReviewSection(Translations.t(lang, 'review_battery'), [
                              (Translations.t(lang, 'battery_cells'), '${provider.wizardBatteryCells}S'),
                              (Translations.t(lang, 'estimated_voltage'), '${voltage.toStringAsFixed(1)}V'),
                              (Translations.t(lang, 'category'), isIndustrial ? Translations.t(lang, 'battery_category_industrial') : Translations.t(lang, 'battery_category_standard')),
                              (Translations.t(lang, 'max_current'), '${isIndustrial ? 200 : 100}A'),
                              (Translations.t(lang, 'max_rpm'), '${isIndustrial ? 100000 : 50000}'),
                            ]),
                            const Divider(color: Colors.white10, height: 24),
                            _buildReviewSection(Translations.t(lang, 'review_motor'), [
                              (Translations.t(lang, 'motor_type_label'), provider.wizardMotorType),
                              (Translations.t(lang, 'pole_pairs'), provider.wizardPolePairs.toString()),
                              (Translations.t(lang, 'kv_rating'), provider.wizardKV.toString()),
                              (Translations.t(lang, 'max_current'), provider.wizardMaxCurrent.toString()),
                              (Translations.t(lang, 'max_rpm'), provider.wizardMaxRPM.toString()),
                            ]),
                            const Divider(color: Colors.white10, height: 24),
                            _buildReviewSection(Translations.t(lang, 'review_sensor'), [
                              (Translations.t(lang, 'sensor_mode_label'), provider.wizardSensorMode),
                            ]),
                            const Divider(color: Colors.white10, height: 24),
                            _buildReviewSection(Translations.t(lang, 'review_control'), [
                              (Translations.t(lang, 'control_mode_label'), provider.wizardControlMode),
                              (Translations.t(lang, 'enable_brake'), provider.wizardBrakeEnabled ? Translations.t(lang, 'brake_enabled') : Translations.t(lang, 'brake_disabled')),
                              (Translations.t(lang, 'pwm_freq'), provider.wizardPWMFreq.toString()),
                              (Translations.t(lang, 'temp_limit'), provider.wizardMaxTemp.toString()),
                              (Translations.t(lang, 'over_current'), provider.wizardOvercurrent.toString()),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AppColors.neonCyan, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.$1, style: TextStyle(color: AppColors.steel, fontSize: 12)),
                Text(item.$2, style: const TextStyle(color: AppColors.tungsten, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

class WizardApplyStep extends StatefulWidget {
  const WizardApplyStep({Key? key}) : super(key: key);

  @override
  State<WizardApplyStep> createState() => _WizardApplyStepState();
}

class _WizardApplyStepState extends State<WizardApplyStep> {
  bool _isApplying = false;
  bool _isComplete = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ESCProvider>(
      builder: (context, provider, _) {
        final lang = provider.currentLanguage.toLowerCase();
        return SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isComplete ? AppColors.success.withOpacity(0.2) : AppColors.electricBlue.withOpacity(0.1),
                        border: Border.all(
                          color: _isComplete ? AppColors.success : AppColors.electricBlue,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isComplete ? Icons.check_circle : Icons.flash_on,
                        size: 60,
                        color: _isComplete ? AppColors.success : AppColors.electricBlue,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _isComplete ? Translations.t(lang, 'configuration_applied') : Translations.t(lang, 'ready_to_apply'),
                      style: TextStyle(
                        color: AppColors.tungsten,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isComplete ? Translations.t(lang, 'apply_success') : Translations.t(lang, 'click_apply'),
                      style: TextStyle(color: AppColors.steel, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (!_isComplete)
                      GlassyCard(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.warning, color: AppColors.alert, size: 32),
                              const SizedBox(height: 16),
                              Text(
                                Translations.t(lang, 'apply_warning'),
                                style: const TextStyle(color: AppColors.tungsten, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                Translations.t(lang, 'ensure_connected'),
                                style: const TextStyle(color: AppColors.steel, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    if (!_isComplete)
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: _isApplying ? Translations.t(lang, 'applying') : Translations.t(lang, 'apply_button'),
                          isLoading: _isApplying,
                          onPressed: _isApplying
                              ? () {}
                              : () async {
                                  setState(() => _isApplying = true);
                                  await Future.delayed(const Duration(seconds: 2));
                                  setState(() {
                                    _isApplying = false;
                                    _isComplete = true;
                                  });
                                },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  }
