import 'dart:async';
import 'package:flutter/material.dart';

class CenteredNotification {
  static OverlayEntry _createEntry(BuildContext context, Widget child) {
    return OverlayEntry(builder: (ctx) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: Center(child: child),
        ),
      );
    });
  }

  /// Show a centered, elegant toast-like notification.
  /// - `message`: the text to show
  /// - `duration`: how long before it disappears
  /// - `success`: controls accent color
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1500),
    bool success = true,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // Use inverted background based on theme:
    // - Dark mode: light (white) background with dark text
    // - Light mode: dark (black) background with light text
    final Color bgColor = isDark ? Colors.white.withOpacity(0.95) : Colors.black87;
    final Color textColor = isDark ? Colors.black87 : Colors.white;

    // Leading icon: success -> green check, error -> red error icon
    final Widget leadingIcon = success
        ? const Icon(Icons.check_circle, color: Color(0xFF8BC34A), size: 20)
        : Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20);

    final Widget child = AnimatedCenteredNotification(
      message: message,
      color: bgColor,
      textColor: textColor,
      leading: leadingIcon,
    );

    final entry = _createEntry(context, child);

    final overlay = Overlay.of(context, rootOverlay: true);
    overlay?.insert(entry);

    Timer(duration, () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }
}

class AnimatedCenteredNotification extends StatefulWidget {
  final String message;
  final Color color;
  final Color textColor;
  final Widget? leading;

  const AnimatedCenteredNotification({Key? key, required this.message, required this.color, required this.textColor, this.leading}) : super(key: key);

  @override
  State<AnimatedCenteredNotification> createState() => _AnimatedCenteredNotificationState();
}

class _AnimatedCenteredNotificationState extends State<AnimatedCenteredNotification> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeIn);
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!.copyWith(color: widget.textColor, fontWeight: FontWeight.w600),
                    child: Text(widget.message, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
