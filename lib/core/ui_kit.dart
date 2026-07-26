// ui_kit.dart — Bold, chunky game widgets (Clash-Royale-ish): heavily framed
// panels and 3D buttons that physically sink when pressed. Built on the tokens
// in theme.dart, so restyling here restyles every screen that uses the kit.

import 'package:flutter/material.dart';

import 'theme.dart';

/// A raised, heavily-framed panel: strong top-lit gradient, a bright top edge,
/// a thick border, and a deep shadow so it reads as a solid physical block.
class GamePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? Colors.white.withValues(alpha: 0.10);
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.panelGradient,
        borderRadius: BorderRadius.circular(AppSpace.radius),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // A bright hairline along the very top sells the "lit from above" look.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    );
    if (onTap == null) return panel;
    return _Pressable(onTap: onTap!, child: panel);
  }
}

/// The signature control: a chunky 3D button with a coloured "lip" beneath.
/// Pressing sinks the face down onto the lip for a tactile, physical feel.
class GameButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final bool dense;

  const GameButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.gradient = AppColors.goGradient,
    this.dense = false,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final faceH = widget.dense ? 42.0 : 54.0;
    const depth = 5.0; // how far the button sits above its lip
    final faceColor = widget.gradient.colors.last;
    final lipColor = enabled ? AppColors.darken(faceColor) : AppColors.surfaceLow;
    final sunk = _down && enabled;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: SizedBox(
        height: faceH + depth,
        child: Stack(
          children: [
            // The lip (bottom base) — the button's shadow made solid.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: faceH + depth,
              child: Container(
                decoration: BoxDecoration(
                  color: lipColor,
                  borderRadius: BorderRadius.circular(AppSpace.radiusSm),
                ),
              ),
            ),
            // The face — moves down onto the lip when pressed.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: sunk ? depth : 0,
              height: faceH,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: enabled
                      ? widget.gradient
                      : const LinearGradient(
                          colors: [AppColors.surfaceHigh, AppColors.surfaceHigh]),
                  borderRadius: BorderRadius.circular(AppSpace.radiusSm),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          color: enabled ? Colors.black : AppColors.muted,
                          size: widget.dense ? 18 : 22),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: enabled ? Colors.black : AppColors.muted,
                        fontSize: widget.dense ? 15 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small caps section label used above groups of content.
class SectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  const SectionLabel(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm, left: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
          ],
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a child with a quick scale-down on press for tactile feedback.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
