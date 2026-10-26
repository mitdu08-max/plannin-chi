import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fond « nocturne » : noir absolu, grille technique très discrète et deux
/// halos cyan / lime. Uniquement des dégradés et un CustomPaint léger — pas de
/// flou plein écran, ça reste fluide sur un téléphone de milieu de gamme.
class NeonBackground extends StatelessWidget {
  final Widget child;
  final bool grid;

  const NeonBackground({super.key, required this.child, this.grid = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.neonInk : AppColors.dayBackground;
    final cyan = isDark ? AppColors.neonCyan : AppColors.dayPrimary;
    final lime = isDark ? AppColors.neonLime : AppColors.daySecondary;

    return DecoratedBox(
      decoration: BoxDecoration(color: base),
      child: Stack(
        children: [
          if (grid)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GridPainter(
                    color: cyan.withValues(alpha: isDark ? 0.055 : 0.06),
                    step: 26,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -170,
            left: -130,
            child: _Halo(
              size: 360,
              color: cyan.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
          ),
          Positioned(
            top: 210,
            right: -150,
            child: _Halo(
              size: 380,
              color: lime.withValues(alpha: isDark ? 0.06 : 0.05),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  final double size;
  final Color color;

  const _Halo({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  final double step;

  const _GridPainter({required this.color, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color || old.step != step;
}

/// Ancien nom conservé pour compatibilité : même fond néon.
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => NeonBackground(child: child);
}

/// Carte de base : angle vif, filet 1 px, fond presque noir.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;
  final bool glow;

  /// Traits d'angle (façon réticule) dans la couleur d'accent.
  final bool brackets;
  final Color? bracketColor;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.gradient,
    this.color,
    this.borderColor,
    this.onTap,
    this.radius = AppRadius.lg,
    this.glow = false,
    this.brackets = false,
    this.bracketColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final accent = bracketColor ?? scheme.primary;

    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? scheme.surface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (glow
                ? accent.withValues(alpha: isDark ? 0.55 : 0.6)
                : scheme.outline),
      ),
      boxShadow: [
        if (glow)
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 26,
            spreadRadius: -4,
          )
        else
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
      ],
    );

    final content = Padding(padding: padding, child: child);

    final body = brackets
        ? _BracketFrame(color: accent, radius: radius, child: content)
        : content;

    if (onTap == null) {
      return Container(decoration: decoration, child: body);
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: body,
        ),
      ),
    );
  }
}

/// Quatre équerres aux angles : le petit détail qui fait « écran technique ».
class _BracketFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const _BracketFrame({required this.child, required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _BracketPainter(color: color, radius: radius)),
          ),
        ),
      ],
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _BracketPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const len = 10.0;
    final r = radius;
    final paths = <Path>[
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, len),
      Path()
        ..moveTo(size.width, size.height - len)
        ..lineTo(size.width, size.height - r)
        ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
        ..lineTo(size.width - len, size.height),
      Path()
        ..moveTo(len, size.height)
        ..lineTo(r, size.height)
        ..quadraticBezierTo(0, size.height, 0, size.height - r)
        ..lineTo(0, size.height - len),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color || old.radius != radius;
}

/// Étiquette technique majuscule (mono, très espacée).
class TechLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;
  final double letterSpacing;
  final FontWeight weight;
  final TextAlign? align;

  const TechLabel(
    this.text, {
    super.key,
    this.color,
    this.size = 9.5,
    this.letterSpacing = 1.6,
    this.weight = FontWeight.w700,
    this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppFonts.tag(
        size: size,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        weight: weight,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

/// Titre de section : carré d'accent + libellé mono + filet.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? accent;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: TechLabel(
                  title,
                  size: 10.5,
                  color: theme.colorScheme.onSurface,
                  weight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(height: 1, color: theme.colorScheme.outline),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Petite pastille d'information — rectangulaire, filet coloré, texte mono.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = filled ? AppColors.neonInk : color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 7 : 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: isDark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: filled ? 0 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppFonts.tag(size: 9, color: fg, weight: FontWeight.w800, letterSpacing: 0.9),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal : aplat cyan → lime, texte encre, halo discret.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final bool expand;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient = AppColors.neon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: AppColors.neonInk),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.monoText(
              size: 12,
              weight: FontWeight.w800,
              color: AppColors.neonInk,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur chiffré : libellé mono, valeur énorme en monospace, unité à part.
class MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final String? hint;

  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TechLabel(label, size: 8.5, letterSpacing: 1.1),
              ),
              Icon(icon, size: 13, color: accent.withValues(alpha: 0.9)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.monoText(
                size: 25,
                weight: FontWeight.w800,
                color: accent,
                letterSpacing: -0.8,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.tag(size: 8, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avatar à initiales : carré à filet, monospace, sans rondeur.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 34,
    this.color,
  });

  static const List<Color> _palette = [
    Color(0xFF00E5FF),
    Color(0xFFB6FF3B),
    Color(0xFFFFC857),
    Color(0xFFFF8AB0),
    Color(0xFF8FD3FF),
    Color(0xFF8AE6C7),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final fg = color ?? _palette[hash % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: fg.withValues(alpha: 0.65)),
      ),
      child: Text(
        initial,
        style: AppFonts.monoText(
          size: size * 0.40,
          weight: FontWeight.w800,
          color: fg,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// État vide / non configuré.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
                boxShadow: AppColors.glow(accent, blur: 22, alpha: 0.18),
              ),
              child: Icon(icon, size: 26, color: accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            TechLabel(
              title,
              size: 11,
              color: theme.colorScheme.onSurface,
              weight: FontWeight.w800,
              letterSpacing: 2,
              align: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Légende des statuts (nuit / congés / repos).
class StatusLegend extends StatelessWidget {
  final List<String> extra;

  const StatusLegend({super.key, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _dot(context, 'Nuit', AppColors.shiftEnd),
        _dot(context, 'Congés', AppColors.vacationStart),
        _dot(context, 'Repos', AppColors.restStart),
        for (final label in extra) _dot(context, label, AppColors.neonAmber),
      ],
    );
  }

  Widget _dot(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, color: color),
        const SizedBox(width: 6),
        TechLabel(label, size: 9, letterSpacing: 1.1),
      ],
    );
  }
}

/// Panneau translucide : filet fin, pas de rondeur.
class FrostedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.neonDeep : Colors.white)
                .withValues(alpha: isDark ? 0.72 : 0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Point qui pulse (garde en cours, import en cours…).
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, required this.color, this.size = 7});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: AppColors.glow(widget.color, blur: 10, alpha: 0.6),
        ),
      ),
    );
  }
}

/// Élément de barre de navigation.
class NeonTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NeonTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Barre de navigation : filet supérieur, libellés mono majuscules, onglet
/// actif en lime avec un trait lumineux au-dessus.
class NeonNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<NeonTab> tabs;

  const NeonNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonLime : AppColors.daySecondary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF060A10).withValues(alpha: 0.97)
            : Colors.white.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _tab(context, i, accent, muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, Color accent, Color muted) {
    final selected = i == index;
    final tab = tabs[i];
    final color = selected ? accent : muted;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: () => onSelect(i),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: AppColors.glow(accent, blur: 10, alpha: 0.8),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tab.label.toUpperCase(),
                    style: AppFonts.tag(
                      size: 8.5,
                      color: color,
                      weight: FontWeight.w800,
                      letterSpacing: 1.1,
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
}
