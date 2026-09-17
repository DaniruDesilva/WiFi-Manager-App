import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A premium 4-digit PIN entry dialog with animated dot indicators and a number pad.
/// 
/// Supports two modes:
/// - **Enter PIN**: User enters their existing PIN to unlock.
/// - **Set PIN**: User enters a new PIN, then confirms it.
class PinDialog extends StatefulWidget {
  /// If true, the dialog asks the user to set a new PIN (with confirmation).
  /// If false, the dialog asks the user to enter an existing PIN.
  final bool isSetMode;
  
  /// Title text shown at the top.
  final String title;

  const PinDialog({
    super.key,
    this.isSetMode = false,
    this.title = 'Enter PIN',
  });

  /// Shows the PIN dialog and returns the entered PIN, or null if cancelled.
  static Future<String?> show(BuildContext context, {bool isSetMode = false, String title = 'Enter PIN'}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinDialog(isSetMode: isSetMode, title: title),
    );
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _firstPin; // Used in set mode for confirmation
  String _currentTitle = '';
  String? _errorMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.isSetMode ? 'Set New PIN' : widget.title;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });

    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _onPinComplete);
    }
  }

  void _onDeletePressed() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _onPinComplete() {
    if (widget.isSetMode) {
      if (_firstPin == null) {
        // First entry — save and ask for confirmation
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _currentTitle = 'Confirm PIN';
        });
      } else {
        // Confirmation entry
        if (_pin == _firstPin) {
          Navigator.of(context).pop(_pin);
        } else {
          _triggerError('PINs do not match. Try again.');
          setState(() {
            _firstPin = null;
            _currentTitle = 'Set New PIN';
          });
        }
      }
    } else {
      // Enter mode — return PIN for verification by caller
      Navigator.of(context).pop(_pin);
    }
  }

  void _triggerError(String message) {
    setState(() {
      _errorMessage = message;
      _pin = '';
    });
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  /// Call this externally if the PIN was wrong (for Enter mode).
  void showError(String message) {
    _triggerError(message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              _currentTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ).animate().shake()
            else
              Text(
                widget.isSetMode && _firstPin == null
                    ? 'Choose a 4-digit PIN'
                    : widget.isSetMode
                        ? 'Re-enter to confirm'
                        : 'Enter your 4-digit PIN',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            const SizedBox(height: 28),

            // Dot Indicators
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final dx = _shakeController.isAnimating
                    ? (10 * (_shakeController.value * 4 * 3.14159).clamp(-1.0, 1.0))
                    : 0.0;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: isFilled ? 20 : 16,
                    height: isFilled ? 20 : 16,
                    decoration: BoxDecoration(
                      color: isFilled ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: _errorMessage != null
                            ? Colors.redAccent
                            : isFilled
                                ? primaryColor
                                : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                        width: 2.5,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),

            // Number Pad
            ..._buildNumberPad(isDark, primaryColor),
            const SizedBox(height: 16),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNumberPad(bool isDark, Color primaryColor) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return rows.map((row) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 56);
            }
            if (key == 'del') {
              return SizedBox(
                width: 72,
                height: 56,
                child: IconButton(
                  onPressed: _onDeletePressed,
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 72,
                height: 56,
                child: Material(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _onDigitPressed(key),
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }
}
