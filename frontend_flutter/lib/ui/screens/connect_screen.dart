import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/esc_provider.dart';
import '../components/modern_components.dart'; // الملف اللي أرسلته لي

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({Key? key}) : super(key: key);

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String? _selectedPort;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ESCProvider>().loadAvailablePorts());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ESCProvider>();
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الجانب الأيسر: حالة الاتصال (Status Visualizer)
                      Expanded(
                        flex: 4,
                        child: GlassyCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _buildStatusSection(provider),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 24),

                      // الجانب الأيمن: قائمة المنافذ والتحكم
                      Expanded(
                        flex: 6,
                        child: GlassyCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _buildPortSelectionSection(provider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // واجهة الحالة (الجزء الأيسر)
  Widget _buildStatusSection(ESCProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("SYSTEM STATUS", style: TextStyle(color: AppColors.steel, fontSize: 12, letterSpacing: 1.5)),
        const SizedBox(height: 32),
        
        // مؤشر بصري كبير للحالة
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
        StatusIndicator( // المكون اللي في ملفك
          isConnected: provider.isConnected,
          label: provider.isConnected ? "CONNECTED" : "OFFLINE",
        ),
        
        if (provider.isConnected) ...[
          const SizedBox(height: 24),
          Text(
            "Port: ${provider.connectedPort}",
            style: const TextStyle(color: AppColors.tungsten, fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }

  // واجهة اختيار المنافذ (الجزء الأيمن)
  Widget _buildPortSelectionSection(ESCProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("AVAILABLE INTERFACES", style: TextStyle(color: AppColors.tungsten, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.neonCyan, size: 20),
              onPressed: () => provider.loadAvailablePorts(),
            )
          ],
        ),
        const Divider(color: Colors.white10),
        const SizedBox(height: 16),

        if (provider.isLoading)
          const LoadingIndicator(message: "Scanning hardware...")
        else if (provider.availablePorts.isEmpty)
          const ErrorMessageWidget(message: "No devices detected. Check USB connection.")
        else
          ...provider.availablePorts.map((port) {
            final isSelected = _selectedPort == port.path;
            return _buildPortTile(port, isSelected);
          }).toList(),

        const SizedBox(height: 32),
        
        // زر الاتصال / قطع الاتصال
        provider.isConnected
            ? HyperButton( // زر الـ Hyper الرهيب حقك
                label: "Disconnect Device",
                onPressed: () => provider.disconnectFromESC(),
              )
            : GradientButton( // زر الـ Gradient حقك
                label: "Establish Connection",
                isLoading: provider.isLoading,
                onPressed: _selectedPort == null ? () {} : () => provider.connectToESC(_selectedPort!),
              ),
      ],
    );
  }

  // تصميم عنصر المنفذ بشكل "Cyber"
  Widget _buildPortTile(dynamic port, bool isSelected) {
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
  }

}