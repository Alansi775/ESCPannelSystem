import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';

// --- PALETTE: Minimalist Black & White with Accent ---
class AppColors {
  static const Color obsidian = Color(0xFF000000); // Pure Black background
  static const Color charcoal = Color(0xFF0F0F0F); // Dark Gray background
  static const Color electricBlue = Color(0xFFE8E8E8); // Light Gray accent
  static const Color neonCyan = Color(0xFFFFFFFF); // Pure White accent
  static const Color tungsten = Color(0xFFFFFFFF); // Primary Text (White)
  static const Color steel = Color(0xFFA0A0A0); // Secondary Text (Gray)
  static const Color alert = Color(0xFFFF3B30); // Error (Red - kept for status)
  static const Color success = Color(0xFF34C759); // Success (Green - kept for status)
}

/// 1. PCB Circuit Background
/// Animated technical background with moving circuit paths (like PCB traces)
class CinematicBackground extends StatefulWidget {
  final Widget child;
  const CinematicBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<CinematicBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Layer - Pure Black
        Container(color: AppColors.obsidian),
        
        // Animated PCB Circuit Paths
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: PCBCircuitPainter(
                animationValue: _controller.value,
                size: MediaQuery.of(context).size,
              ),
              size: Size.infinite,
            );
          },
        ),

        // Vignette overlay - keeps PCB traces only on sides, clears center for content
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.8,
              center: const Alignment(0.0, 0.0),
              colors: [
                Colors.black.withOpacity(0.5), // Very strong center - hides all traces
                Colors.black.withOpacity(0.3), // Medium fade
                Colors.black.withOpacity(0.0), // Transparent edges only
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Additional overlay to clear bottom area where text and buttons sit
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.4), // Strong at bottom
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        
        // Subtle Noise Texture
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.01),
                Colors.black.withOpacity(0.01),
              ],
            ),
          ),
        ),

        // Content
        widget.child,
      ],
    );
  }
}

/// PCB Circuit Painter - Creates authentic PCB traces with right angles
class PCBCircuitPainter extends CustomPainter {
  final double animationValue;
  final Size size;

  PCBCircuitPainter({required this.animationValue, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.electricBlue.withOpacity(0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    final nodePaint = Paint()
      ..color = AppColors.neonCyan.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw multiple PCB traces
    _drawPCBTraces(canvas, size, linePaint, nodePaint);
  }

  void _drawPCBTraces(Canvas canvas, Size size, Paint linePaint, Paint nodePaint) {
    final traceCount = 12; // More traces for complexity
    
    for (int i = 0; i < traceCount; i++) {
      // Each trace has its own random seed based on index and time
      final seed = (animationValue * 8).floor() + i;
      final random = Random(seed);
      
      // Random visibility - traces appear and disappear
      final visibility = ((sin(animationValue * 2.2 + i * 0.6) + 1) / 2);
      
      if (visibility > 0.2) {
        _drawSinglePCBTrace(canvas, size, i, linePaint, nodePaint, visibility);
      }
    }
  }

  void _drawSinglePCBTrace(
    Canvas canvas,
    Size size,
    int traceIndex,
    Paint linePaint,
    Paint nodePaint,
    double visibility,
  ) {
    final random = Random(traceIndex * 127);
    
    // Define safe zones - traces only in edges (avoid center)
    final edgeMargin = size.width * 0.25; // 25% from each side = center 50% is empty
    final verticalMargin = size.height * 0.2;
    
    // Starting point - always from edges in the margin zones
    late Offset currentPoint;
    late String currentDirection; // track direction to move along edges
    
    final startSide = traceIndex % 4;
    
    switch (startSide) {
      case 0: // Top edge - horizontal movement
        currentPoint = Offset(
          random.nextDouble() * edgeMargin, // Start from left edge area
          20 + random.nextDouble() * 60,
        );
        currentDirection = 'right';
        break;
      case 1: // Right edge - vertical movement
        currentPoint = Offset(
          size.width - (random.nextDouble() * edgeMargin),
          20 + random.nextDouble() * 60,
        );
        currentDirection = 'down';
        break;
      case 2: // Bottom edge - horizontal movement
        currentPoint = Offset(
          size.width - (random.nextDouble() * edgeMargin),
          size.height - (20 + random.nextDouble() * 60),
        );
        currentDirection = 'left';
        break;
      default: // Left edge - vertical movement
        currentPoint = Offset(
          random.nextDouble() * edgeMargin,
          size.height - (20 + random.nextDouble() * 60),
        );
        currentDirection = 'up';
    }

    final tracePath = Path();
    tracePath.moveTo(currentPoint.dx, currentPoint.dy);

    // Draw segments that stay in edge zones
    final segmentCount = 4 + (traceIndex % 4);
    
    for (int i = 0; i < segmentCount; i++) {
      final length = 60 + random.nextInt(100);
      late Offset nextPoint;
      
      // Move based on current direction, then potentially turn 90 degrees
      switch (currentDirection) {
        case 'right':
          nextPoint = Offset(currentPoint.dx + length, currentPoint.dy);
          if (random.nextBool()) {
            currentDirection = random.nextBool() ? 'up' : 'down';
          }
          break;
        case 'left':
          nextPoint = Offset(currentPoint.dx - length, currentPoint.dy);
          if (random.nextBool()) {
            currentDirection = random.nextBool() ? 'up' : 'down';
          }
          break;
        case 'up':
          nextPoint = Offset(currentPoint.dx, currentPoint.dy - length);
          if (random.nextBool()) {
            currentDirection = random.nextBool() ? 'left' : 'right';
          }
          break;
        case 'down':
          nextPoint = Offset(currentPoint.dx, currentPoint.dy + length);
          if (random.nextBool()) {
            currentDirection = random.nextBool() ? 'left' : 'right';
          }
          break;
        default:
          nextPoint = currentPoint;
      }
      
      // Keep points in edge zones only
      nextPoint = Offset(
        nextPoint.dx.clamp(-50.0, size.width + 50.0),
        nextPoint.dy.clamp(-50.0, size.height + 50.0),
      );
      
      // If point tries to enter center zone, skip it
      final isInCenterX = nextPoint.dx > edgeMargin && nextPoint.dx < (size.width - edgeMargin);
      final isInCenterY = nextPoint.dy > verticalMargin && nextPoint.dy < (size.height - verticalMargin);
      
      if (isInCenterX && isInCenterY) {
        // Don't draw this segment, move to edge
        continue;
      }

      tracePath.lineTo(nextPoint.dx, nextPoint.dy);
      
      // Add vias at corners only
      if (i > 0 && random.nextInt(4) == 0 && !isInCenterX && !isInCenterY) {
        canvas.drawCircle(
          nextPoint,
          2.5 * visibility,
          Paint()
            ..color = AppColors.electricBlue.withOpacity(0.4 * visibility)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          nextPoint,
          1.2 * visibility,
          Paint()
            ..color = AppColors.obsidian
            ..style = PaintingStyle.fill,
        );
      }
      
      currentPoint = nextPoint;
    }

    // Apply visibility opacity
    final tracePaint = Paint()
      ..color = AppColors.electricBlue.withOpacity(0.3 * visibility)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    canvas.drawPath(tracePath, tracePaint);

    // Draw connection nodes at regular intervals
    final nodeOpacity = visibility;
    final nodeRadius = 2.2 * visibility;
    
    try {
      tracePath.computeMetrics().forEach((metric) {
        for (double i = 0; i < metric.length; i += 25) {
          final tan = metric.getTangentForOffset(i);
          if (tan != null) {
            canvas.drawCircle(
              tan.position,
              nodeRadius,
              Paint()
                ..color = AppColors.neonCyan.withOpacity(0.3 * nodeOpacity)
                ..style = PaintingStyle.fill,
            );
          }
        }
      });
    } catch (e) {
      // Silently handle computeMetrics errors
    }

    // Draw pulse moving along the trace
    try {
      final metrics = tracePath.computeMetrics();
      final totalLength = metrics.fold<double>(0, (sum, metric) => sum + metric.length);
      
      if (totalLength > 0) {
        final pulseOffset = (animationValue * 350 + traceIndex * 40) % totalLength;
        
        var distance = 0.0;
        for (final metric in metrics) {
          if (distance + metric.length > pulseOffset) {
            final offsetInMetric = pulseOffset - distance;
            final tan = metric.getTangentForOffset(offsetInMetric);
            if (tan != null) {
              canvas.drawCircle(
                tan.position,
                4.0 * visibility,
                Paint()
                  ..color = AppColors.neonCyan.withOpacity(0.75 * visibility)
                  ..style = PaintingStyle.fill,
              );

              // Glow
              canvas.drawCircle(
                tan.position,
                8.5 * visibility,
                Paint()
                  ..color = AppColors.electricBlue.withOpacity(0.2 * visibility)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 0.8,
              );
            }
            break;
          }
          distance += metric.length;
        }
      }
    } catch (e) {
      // Silently handle pulse animation errors
    }
  }

  @override
  bool shouldRepaint(PCBCircuitPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

/// 2. Holographic Glass Card
/// The main container for forms. Looks like premium hardware glass.
class HolographicCard extends StatelessWidget {
  final Widget child;
  const HolographicCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.charcoal.withOpacity(0.6),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.02),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 3. Cyber Input Field
/// Input that glows when focused.
class CyberInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const CyberInput({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  }) : super(key: key);

  @override
  State<CyberInput> createState() => _CyberInputState();
}

class _CyberInputState extends State<CyberInput> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.obsidian.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? AppColors.electricBlue : Colors.white.withOpacity(0.1),
            width: _isFocused ? 1.5 : 1,
          ),
          boxShadow: _isFocused
              ? [BoxShadow(color: AppColors.electricBlue.withOpacity(0.3), blurRadius: 12)]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'), // Assuming Roboto or System
          cursorColor: AppColors.electricBlue,
          validator: widget.validator,
          decoration: InputDecoration(
            prefixIcon: Icon(
              widget.icon,
              color: _isFocused ? AppColors.electricBlue : AppColors.steel,
            ),
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _isFocused ? AppColors.electricBlue : AppColors.steel,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            errorStyle: const TextStyle(color: AppColors.alert, height: 0.8),
          ),
        ),
      ),
    );
  }
}

/// 4. Hyper Button
/// "Alive" button with gradient and scale animation.
class HyperButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const HyperButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<HyperButton> createState() => _HyperButtonState();
}

class _HyperButtonState extends State<HyperButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      lowerBound: 0.98,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.reverse(),
        onTapUp: (_) => _controller.forward(),
        onTapCancel: () => _controller.forward(),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _controller,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: _isHovered
                    ? [const Color(0xFF2962FF), const Color(0xFF00B0FF)]
                    : [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.electricBlue.withOpacity(_isHovered ? 0.6 : 0.3),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 5. Language Pill
class LanguageSelector extends StatelessWidget {
  final String currentLang;
  final Function(String) onSelect;

  const LanguageSelector({Key? key, required this.currentLang, required this.onSelect}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.obsidian.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langOption('TR', currentLang == 'tr'),
          _langOption('EN', currentLang == 'en'),
        ],
      ),
    );
  }

  Widget _langOption(String code, bool isActive) {
    return GestureDetector(
      onTap: () => onSelect(code.toLowerCase()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          code,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.steel,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// 6. Status Indicator
class StatusIndicator extends StatelessWidget {
  final bool isConnected;
  final String label;

  const StatusIndicator({
    Key? key,
    required this.isConnected,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.success.withOpacity(0.1)
            : AppColors.alert.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.alert,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? AppColors.success : AppColors.alert,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? AppColors.success : AppColors.alert)
                      .withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isConnected ? AppColors.success : AppColors.alert,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// 7. Loading Indicator
class LoadingIndicator extends StatefulWidget {
  final String message;

  const LoadingIndicator({
    Key? key,
    this.message = 'Loading...',
  }) : super(key: key);

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.electricBlue.withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: CustomPaint(
                painter: _LoadingPainter(_controller.value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.message,
            style: const TextStyle(
              color: AppColors.tungsten,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPainter extends CustomPainter {
  final double value;

  _LoadingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.electricBlue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      value * 2 * 3.14159,
      1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_LoadingPainter oldDelegate) => oldDelegate.value != value;
}

/// 8. Error Message Widget
class ErrorMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorMessageWidget({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.alert.withOpacity(0.1),
              border: Border.all(
                color: AppColors.alert,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.alert,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.tungsten,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 9. Glassy Card (Frosted Glass Effect)
class GlassyCard extends StatelessWidget {
  final Widget child;
  final double blur;

  const GlassyCard({
    Key? key,
    required this.child,
    this.blur = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 10. Gradient Button
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const GradientButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.electricBlue,
                AppColors.neonCyan,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.electricBlue.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.electricBlue.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}