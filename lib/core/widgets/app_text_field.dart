import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Champ de texte premium FitForge AI.
///
/// Glassmorphisme + glow au focus + animations d'icône.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final bool autofocus;
  final Color? accentColor;
  final int? maxLines;

  const AppTextField({
    super.key,
    this.controller,
    required this.hint,
    this.label,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.autofocus = false,
    this.accentColor,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _focusCtrl;
  late final Animation<double> _focusAnim;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnim = CurvedAnimation(parent: _focusCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _focusCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
    if (hasFocus) {
      _focusCtrl.forward();
    } else {
      _focusCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.labelSmall.copyWith(
              color: _isFocused ? accentColor : AppColors.textHint,
              fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(widget.label!),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: _focusAnim,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: 0.25 * _focusAnim.value,
                          ),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: Focus(
            onFocusChange: _onFocusChange,
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onChanged: widget.onChanged,
              textInputAction: widget.textInputAction,
              autofocus: widget.autofocus,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              style: AppTextStyles.bodyLarge,
              cursorColor: accentColor,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: true,
                fillColor: _isFocused
                    ? AppColors.glassWhiteMid
                    : AppColors.glassWhite,
                prefixIcon: widget.prefixIcon != null
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        child: Icon(
                          widget.prefixIcon,
                          color: _isFocused ? accentColor : AppColors.textHint,
                          size: 22,
                        ),
                      )
                    : null,
                suffixIcon: widget.suffix,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
