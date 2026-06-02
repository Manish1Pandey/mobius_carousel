import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mobius_item.dart';
import 'mobius_ripple_style.dart';

/// A tilted-stack carousel of branded "ticket" cards with infinite-wrap
/// swipe, auto-play, a rubber-band pull-to-claim gesture, an optional
/// confetti burst, and an optional non-dismissable claim dialog.
///
/// Pass the [items] list to render — every other parameter has a sensible
/// default. The center item is fully visible; neighbors fan out, tilted
/// and lifted, with an infinite-wrap horizontal swipe.
///
/// ```dart
/// MobiusCarousel(
///   items: [MobiusItem(provider: 'BESCOM', billAmount: '₹2,400')],
///   onOfferClaimed: (item) => print('claimed \${item.provider}'),
/// )
/// ```
class MobiusCarousel extends StatefulWidget {
  /// Items rendered as cards. Required, but may be empty.
  final List<MobiusItem> items;

  /// Widget shown above the carousel.
  final Widget? header;

  /// Widget shown below the carousel.
  final Widget? footer;

  /// Visual gap in pixels between the center card and each side card.
  final double sideCardGap;

  /// Card width in logical pixels.
  final double cardWidth;

  /// Card height in logical pixels.
  final double cardHeight;

  /// Inward tilt of the left neighbor card in degrees. Positive values
  /// lean the top of the card toward the center.
  final double leftCardTiltDegrees;

  /// Inward tilt of the right neighbor card in degrees. Positive values
  /// lean the top of the card toward the center.
  final double rightCardTiltDegrees;

  /// Extra positional offset for the left neighbor card relative to its
  /// standard position. Scaled by distance for farther neighbors.
  final Offset leftCardOffset;

  /// Extra positional offset for the right neighbor card relative to its
  /// standard position. Scaled by distance for farther neighbors.
  final Offset rightCardOffset;

  /// Index of the item centered on first build.
  final int initialIndex;

  /// Scaffold background color. Defaults to the surrounding theme.
  final Color? backgroundColor;

  /// Called when the user taps the centered (focused) card. Side-card
  /// taps still re-center that card; only the focused card invokes this
  /// callback.
  final void Function(MobiusItem item)? onCenterCardTap;

  /// Called when the user pulls the center card past [claimThreshold]
  /// pixels downward. Fires once per pull.
  final void Function(MobiusItem item)? onOfferClaimed;

  /// Pull distance in pixels required to claim the offer.
  final double claimThreshold;

  /// Whether to play the built-in confetti burst on claim.
  final bool showConfetti;

  /// Whether to show the built-in non-dismissable "Offer Claimed" dialog
  /// on claim. Set to `false` to handle the post-claim UI yourself from
  /// inside [onOfferClaimed].
  final bool showClaimedDialog;

  /// Called after the user taps "Awesome!" in the built-in dialog. The
  /// dialog is popped first, then the callback fires with the parent
  /// [BuildContext] and the claimed [MobiusItem]. Use this to navigate to
  /// any destination (`Navigator.pushNamed`, `MaterialPageRoute`, etc.).
  final void Function(BuildContext context, MobiusItem item)? onClaimConfirmed;

  /// Interval between auto-advances of the carousel. Pauses while the
  /// user is dragging (horizontal or vertical) and while the claim dialog
  /// is open; resumes afterwards. Pass `null` to disable auto-play.
  final Duration? autoPlayInterval;

  /// Visual ripple style drawn behind the cards while the user pulls the
  /// center card downward.
  final MobiusRippleStyle rippleStyle;

  /// Optional builder that replaces the built-in ticket card visual with
  /// any widget you supply. Receives the [BuildContext], the [MobiusItem]
  /// for that slot, and whether the card is currently focused (centered).
  /// Returned widget is automatically sized to `cardWidth × cardHeight`,
  /// wrapped in the tap handler, and laid into the tilted stack — all
  /// other carousel interactions (drag, claim, confetti, dialog) continue
  /// to work unchanged.
  ///
  /// When `null` (default), the built-in scallop-edged ticket card is
  /// used and reads from the [MobiusItem] fields.
  final Widget Function(
    BuildContext context,
    MobiusItem item,
    bool isFocused,
  )? cardBuilder;

  /// Creates a [MobiusCarousel].
  const MobiusCarousel({
    super.key,
    required this.items,
    this.header,
    this.footer,
    this.sideCardGap = 80,
    this.cardWidth = 180,
    this.cardHeight = 290,
    this.leftCardTiltDegrees = 23,
    this.rightCardTiltDegrees = 23,
    this.leftCardOffset = const Offset(0, -80),
    this.rightCardOffset = const Offset(0, -80),
    this.initialIndex = 1,
    this.backgroundColor,
    this.onCenterCardTap,
    this.onOfferClaimed,
    this.claimThreshold = 120,
    this.showConfetti = true,
    this.showClaimedDialog = true,
    this.onClaimConfirmed,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.rippleStyle = MobiusRippleStyle.wavy,
    this.cardBuilder,
  });

  @override
  State<MobiusCarousel> createState() => _MobiusCarouselState();
}

class _MobiusCarouselState extends State<MobiusCarousel>
    with TickerProviderStateMixin {
  // Reactive state (vanilla — no third-party state management).
  final ValueNotifier<double> _position = ValueNotifier<double>(0);
  final ValueNotifier<double> _verticalDrag = ValueNotifier<double>(0);

  // Animation controllers.
  late final AnimationController _snapController;
  late final AnimationController _bounceController;
  late final AnimationController _confettiController;

  Animation<double>? _snapAnimation;
  Animation<double>? _bounceAnimation;

  // Auto-play.
  Timer? _autoPlayTimer;

  // Per-pull guard for the claim callback.
  bool _claimedThisDrag = false;

  static const double _maxVerticalDrag = 180;

  @override
  void initState() {
    super.initState();
    _position.value = widget.initialIndex.toDouble();

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        if (_snapAnimation != null) {
          _position.value = _snapAnimation!.value;
        }
      });

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
        if (_bounceAnimation != null) {
          _verticalDrag.value = _bounceAnimation!.value;
        }
      });

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    final interval = widget.autoPlayInterval;
    if (interval != null && widget.items.length > 1) {
      _startAutoPlay(interval);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _verticalDrag.dispose();
    _snapController.dispose();
    _bounceController.dispose();
    _confettiController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────── auto-play ────────────────────────

  void _startAutoPlay(Duration interval) {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(interval, (_) {
      if (_snapController.isAnimating || _bounceController.isAnimating) return;
      _animateTo(
        _position.value.roundToDouble() + 1,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _resumeAutoPlay() {
    final interval = widget.autoPlayInterval;
    if (interval != null && widget.items.length > 1) {
      _startAutoPlay(interval);
    }
  }

  // ──────────────────────── animation ────────────────────────

  void _animateTo(
    double target, {
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeOutCubic,
  }) {
    _snapController.duration = duration;
    _snapAnimation = Tween<double>(begin: _position.value, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: curve),
    );
    _snapController.forward(from: 0);
  }

  void _snapBackVertical() {
    _bounceAnimation = Tween<double>(begin: _verticalDrag.value, end: 0)
        .animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    _bounceController.forward(from: 0);
  }

  // ──────────────────────── gestures ────────────────────────

  void _onHorizontalDragStart() {
    _pauseAutoPlay();
    if (_snapController.isAnimating) _snapController.stop();
    if (_verticalDrag.value > 0) _snapBackVertical();
  }

  void _onHorizontalDragUpdate(double deltaX, double itemSpacing) {
    _position.value = _position.value - deltaX / itemSpacing;
  }

  void _onHorizontalDragEnd(double velocityX, double itemSpacing) {
    final flick = -velocityX / itemSpacing * 0.12;
    final target = (_position.value + flick).roundToDouble();
    _animateTo(target);
    _resumeAutoPlay();
  }

  void _onVerticalDragStart() {
    _pauseAutoPlay();
    if (_bounceController.isAnimating) _bounceController.stop();
    _claimedThisDrag = false;
  }

  void _onVerticalDragUpdate(double dy) {
    if (dy > 0) {
      final progress = (_verticalDrag.value / _maxVerticalDrag).clamp(0.0, 1.0);
      final resistance = (1 - progress).clamp(0.0, 1.0);
      _verticalDrag.value =
          (_verticalDrag.value + dy * resistance).clamp(0.0, _maxVerticalDrag);
    } else {
      final next = _verticalDrag.value + dy;
      _verticalDrag.value = next < 0 ? 0 : next;
    }

    if (!_claimedThisDrag &&
        widget.items.isNotEmpty &&
        _verticalDrag.value >= widget.claimThreshold) {
      _claimedThisDrag = true;
      final claimed = widget.items[_wrappedCenterIndex()];
      widget.onOfferClaimed?.call(claimed);
      if (widget.showConfetti) _confettiController.forward(from: 0);
      if (widget.showClaimedDialog) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _showClaimedDialog(claimed);
        });
      }
    }
  }

  void _onVerticalDragEnd() {
    _snapBackVertical();
    _resumeAutoPlay();
  }

  void _jumpTo(int index) {
    _animateTo(index.toDouble());
  }

  int _wrappedCenterIndex() {
    final n = widget.items.length;
    if (n == 0) return 0;
    final raw = _position.value.round();
    return ((raw % n) + n) % n;
  }

  void _showClaimedDialog(MobiusItem item) {
    final parentContext = context;
    _pauseAutoPlay();
    showDialog<void>(
      context: parentContext,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: _OfferClaimedDialog(
          item: item,
          showConfetti: widget.showConfetti,
          onConfirm: () {
            Navigator.of(dialogContext).pop();
            widget.onClaimConfirmed?.call(parentContext, item);
          },
        ),
      ),
    ).then((_) {
      if (mounted) _resumeAutoPlay();
    });
  }

  // ──────────────────────── build ────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Ripple overlay (behind cards).
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_position, _verticalDrag]),
                  builder: (context, _) => _buildRipple(),
                ),
              ),
            ),
            // Main carousel column.
            Column(
              children: [
                const SizedBox(height: 12),
                if (widget.header != null) widget.header!,
                const SizedBox(height: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final itemSpacing = widget.cardWidth + widget.sideCardGap;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) => _onHorizontalDragStart(),
                        onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(
                          d.delta.dx,
                          itemSpacing,
                        ),
                        onHorizontalDragEnd: (d) => _onHorizontalDragEnd(
                          d.velocity.pixelsPerSecond.dx,
                          itemSpacing,
                        ),
                        onVerticalDragStart: (_) => _onVerticalDragStart(),
                        onVerticalDragUpdate: (d) =>
                            _onVerticalDragUpdate(d.delta.dy),
                        onVerticalDragEnd: (_) => _onVerticalDragEnd(),
                        child: Center(
                          child: AnimatedBuilder(
                            animation:
                                Listenable.merge([_position, _verticalDrag]),
                            builder: (context, _) => _MobiusStack(
                              items: widget.items,
                              position: _position.value,
                              verticalDrag: _verticalDrag.value,
                              itemSpacing: itemSpacing,
                              cardWidth: widget.cardWidth,
                              cardHeight: widget.cardHeight,
                              leftTiltRadians:
                                  widget.leftCardTiltDegrees * math.pi / 180,
                              rightTiltRadians:
                                  widget.rightCardTiltDegrees * math.pi / 180,
                              leftCardOffset: widget.leftCardOffset,
                              rightCardOffset: widget.rightCardOffset,
                              onJumpTo: _jumpTo,
                              onCenterCardTap: widget.onCenterCardTap,
                              cardBuilder: widget.cardBuilder,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.footer != null) widget.footer!,
                const SizedBox(height: 16),
              ],
            ),
            // Confetti overlay (above cards).
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    final v = _confettiController.value;
                    if (v == 0 || v >= 1) return const SizedBox.shrink();
                    return CustomPaint(
                      painter: _ConfettiPainter(progress: v),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRipple() {
    if (widget.rippleStyle == MobiusRippleStyle.none || widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final drag = _verticalDrag.value;
    if (drag <= 0) return const SizedBox.shrink();
    final color =
        widget.items[_wrappedCenterIndex()].color ?? const Color(0xFFE91E63);
    final progress = drag / widget.claimThreshold;
    return CustomPaint(
      painter: switch (widget.rippleStyle) {
        MobiusRippleStyle.wavy =>
          _WavyRipplePainter(progress: progress, color: color),
        MobiusRippleStyle.circular =>
          _CircularRipplePainter(progress: progress, color: color),
        MobiusRippleStyle.semiCircle =>
          _SemiCircleRipplePainter(progress: progress, color: color),
        MobiusRippleStyle.none => null,
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Internal widgets and painters below — not part of the public API.
// ══════════════════════════════════════════════════════════════════

class _MobiusStack extends StatelessWidget {
  final List<MobiusItem> items;
  final double position;
  final double verticalDrag;
  final double itemSpacing;
  final double cardWidth;
  final double cardHeight;
  final double leftTiltRadians;
  final double rightTiltRadians;
  final Offset leftCardOffset;
  final Offset rightCardOffset;
  final ValueChanged<int> onJumpTo;
  final void Function(MobiusItem item)? onCenterCardTap;
  final Widget Function(
    BuildContext context,
    MobiusItem item,
    bool isFocused,
  )? cardBuilder;

  const _MobiusStack({
    required this.items,
    required this.position,
    required this.verticalDrag,
    required this.itemSpacing,
    required this.cardWidth,
    required this.cardHeight,
    required this.leftTiltRadians,
    required this.rightTiltRadians,
    required this.leftCardOffset,
    required this.rightCardOffset,
    required this.onJumpTo,
    required this.onCenterCardTap,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    if (count == 0) return const SizedBox.shrink();

    final entries = <_MobiusEntry>[];
    final base = position.round();
    for (var i = base - 2; i <= base + 2; i++) {
      final offset = i - position;
      final distance = offset.abs();
      if (distance > 1.3) continue;
      if (count <= 1 && i != base) continue;

      final sideOffset = offset < 0 ? leftCardOffset : rightCardOffset;
      final isCenter = distance < 0.5;
      final dx = offset * itemSpacing + sideOffset.dx * distance;
      final dy = sideOffset.dy * distance + (isCenter ? verticalDrag : 0);
      final scale = (1.0 - distance * 0.04).clamp(0.94, 1.0);
      final rotation =
          offset < 0 ? -offset * leftTiltRadians : -offset * rightTiltRadians;
      final opacity =
          distance <= 1.0 ? 1.0 : (1.0 - (distance - 1.0) * 3).clamp(0.0, 1.0);

      final itemIndex = ((i % count) + count) % count;
      final item = items[itemIndex];
      final entryIndex = i;

      void handleTap() {
        if (distance < 0.5 && onCenterCardTap != null) {
          onCenterCardTap!(item);
        } else {
          onJumpTo(entryIndex);
        }
      }

      final Widget card;
      if (item.child != null) {
        card = SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: GestureDetector(onTap: handleTap, child: item.child),
        );
      } else if (cardBuilder != null) {
        card = SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: GestureDetector(
            onTap: handleTap,
            child: cardBuilder!(context, item, isCenter),
          ),
        );
      } else {
        card = _MobiusCard(
          item: item,
          width: cardWidth,
          height: cardHeight,
          isFocused: isCenter,
          onTap: handleTap,
        );
      }

      entries.add(
        _MobiusEntry(
          distance: distance,
          widget: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Opacity(opacity: opacity, child: card),
              ),
            ),
          ),
        ),
      );
    }

    entries.sort((a, b) => b.distance.compareTo(a.distance));

    return Stack(
      alignment: Alignment.center,
      children: entries.map((e) => e.widget).toList(),
    );
  }
}

class _MobiusEntry {
  final double distance;
  final Widget widget;
  _MobiusEntry({required this.distance, required this.widget});
}

class _MobiusCard extends StatelessWidget {
  final MobiusItem item;
  final double width;
  final double height;
  final bool isFocused;
  final VoidCallback onTap;

  const _MobiusCard({
    required this.item,
    required this.width,
    required this.height,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? const Color(0xFFE91E63);
    final softTint =
        Color.alphaBlend(color.withValues(alpha: 0.10), Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? color.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isFocused ? 30 : 14,
              offset: isFocused ? const Offset(0, 14) : const Offset(0, 6),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const _NotchedClipper(),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: softTint,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: _CodeChip(code: item.code ?? '', color: color),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.logo ?? Icons.local_offer,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.provider ?? '',
                  style: const TextStyle(
                    color: Color(0xFF1B1B1B),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.accountNumber ?? '',
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(color: const Color(0xFFE0E0E0)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bill Amount',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.billAmount ?? '',
                  style: const TextStyle(
                    color: Color(0xFF1B1B1B),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
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

class _CodeChip extends StatelessWidget {
  final String code;
  final Color color;
  const _CodeChip({required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color.withValues(alpha: 0.55),
        radius: 6,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────── Claim dialog ────────────────────────

class _OfferClaimedDialog extends StatefulWidget {
  final MobiusItem item;
  final VoidCallback onConfirm;
  final bool showConfetti;

  const _OfferClaimedDialog({
    required this.item,
    required this.onConfirm,
    required this.showConfetti,
  });

  @override
  State<_OfferClaimedDialog> createState() => _OfferClaimedDialogState();
}

class _OfferClaimedDialogState extends State<_OfferClaimedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.showConfetti) _confettiCtrl.forward();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = item.color ?? const Color(0xFFE91E63);
    final darker = Color.lerp(color, Colors.black, 0.30)!;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (context, _) {
                final v = _confettiCtrl.value;
                if (v == 0 || v >= 1) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _ConfettiPainter(progress: v, originYFraction: 0.5),
                );
              },
            ),
          ),
        ),
        _buildDialogCard(color, darker),
      ],
    );
  }

  Widget _buildDialogCard(Color color, Color darker) {
    final item = widget.item;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [color, darker]),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.50),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Offer Claimed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: Color(0xFF6B6B6B),
                  ),
                  children: [
                    TextSpan(
                      text: item.billAmount ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    const TextSpan(text: ' from '),
                    TextSpan(
                      text: item.provider ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    color.withValues(alpha: 0.10),
                    Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.logo ?? Icons.local_offer,
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.code ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────── Painters / clippers ────────────────────────

class _NotchedClipper extends CustomClipper<Path> {
  const _NotchedClipper();
  static const double _cornerR = 14;
  static const double _notchR = 5;
  static const double _notchSpacing = 18;

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    final usable = w - 2 * _cornerR;
    final count = (usable / _notchSpacing).floor();
    if (count <= 0) {
      return path
        ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_cornerR),
        ));
    }
    final spacing = usable / count;

    path.moveTo(0, _cornerR);
    path.quadraticBezierTo(0, 0, _cornerR, 0);

    for (var i = 0; i < count; i++) {
      final cx = _cornerR + spacing * (i + 0.5);
      path.lineTo(cx - _notchR, 0);
      path.arcToPoint(
        Offset(cx + _notchR, 0),
        radius: const Radius.circular(_notchR),
        clockwise: true,
      );
    }
    path.lineTo(w - _cornerR, 0);
    path.quadraticBezierTo(w, 0, w, _cornerR);
    path.lineTo(w, h - _cornerR);
    path.quadraticBezierTo(w, h, w - _cornerR, h);

    for (var i = count - 1; i >= 0; i--) {
      final cx = _cornerR + spacing * (i + 0.5);
      path.lineTo(cx + _notchR, h);
      path.arcToPoint(
        Offset(cx - _notchR, h),
        radius: const Radius.circular(_notchR),
        clockwise: true,
      );
    }
    path.lineTo(_cornerR, h);
    path.quadraticBezierTo(0, h, 0, h - _cornerR);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = (dist + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _WavyRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  static const int _maxRipples = 6;
  static const double _bottomPad = 110;
  static const double _rippleGap = 16;

  _WavyRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final active = progress.clamp(0.0, 1.2);
    for (var i = 0; i < _maxRipples; i++) {
      final threshold = (i / _maxRipples) * 0.55;
      final local = ((active - threshold) / 0.45).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = size.height - _bottomPad - (i * _rippleGap);
      final baseAlpha = 0.55 - i * 0.04;
      final alpha = (local * baseAlpha).clamp(0.0, 1.0);
      final amplitude = 5.0 + i * 1.6;
      final wavelength = size.width / (4 - i * 0.25);
      final phase = i * 0.7;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 3) {
        final waveY =
            y + math.sin((x / wavelength) * 2 * math.pi + phase) * amplitude;
        path.lineTo(x, waveY);
      }
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + local * 0.6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavyRipplePainter old) =>
      old.progress != progress || old.color != color;
}

class _CircularRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  static const int _maxRings = 6;
  static const double _baseRadius = 38;
  static const double _ringGap = 34;
  static const double _originBottomPad = 100;

  _CircularRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final active = progress.clamp(0.0, 1.2);
    final cx = size.width / 2;
    final cy = size.height - _originBottomPad;
    for (var i = 0; i < _maxRings; i++) {
      final threshold = (i / _maxRings) * 0.55;
      final local = ((active - threshold) / 0.45).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final radius = _baseRadius + i * _ringGap;
      final baseAlpha = 0.55 - i * 0.05;
      final alpha = (local * baseAlpha).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + local * 0.6
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CircularRipplePainter old) =>
      old.progress != progress || old.color != color;
}

class _SemiCircleRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  static const int _maxArches = 6;
  static const double _baseRadius = 80;
  static const double _archGap = 32;
  static const double _bottomPad = 30;

  _SemiCircleRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final active = progress.clamp(0.0, 1.2);
    final cx = size.width / 2;
    final cy = size.height - _bottomPad;
    for (var i = 0; i < _maxArches; i++) {
      final threshold = (i / _maxArches) * 0.55;
      final local = ((active - threshold) / 0.45).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final radius = _baseRadius + i * _archGap;
      final baseAlpha = 0.55 - i * 0.05;
      final alpha = (local * baseAlpha).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + local * 0.6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        math.pi,
        math.pi,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SemiCircleRipplePainter old) =>
      old.progress != progress || old.color != color;
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final double originYFraction;
  static const int _count = 60;
  static const List<Color> _palette = [
    Color(0xFFE91E63),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF5722),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];

  _ConfettiPainter({required this.progress, this.originYFraction = 0.42});

  @override
  void paint(Canvas canvas, Size size) {
    final originX = size.width / 2;
    final originY = size.height * originYFraction;
    final t = progress;
    final fade = (1 - t * t).clamp(0.0, 1.0);
    for (var i = 0; i < _count; i++) {
      final r1 = ((i * 73 + 47) % 100) / 100;
      final r2 = ((i * 37 + 91) % 100) / 100;
      final r3 = ((i * 13 + 7) % 100) / 100;
      final angle = -math.pi / 2 + (r1 - 0.5) * math.pi * 1.1;
      final speed = 280 + r2 * 260;
      const gravity = 700.0;
      final dx = math.cos(angle) * speed * t;
      final dy = math.sin(angle) * speed * t + 0.5 * gravity * t * t;
      final x = originX + dx;
      final y = originY + dy;
      final color = _palette[i % _palette.length];
      final rotation =
          (r3 * 2 * math.pi) + (i.isEven ? 1 : -1) * t * 6 * math.pi;
      final w = 6 + r2 * 4;
      final h = 3 + r3 * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Paint()..color = color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.progress != progress || old.originYFraction != originYFraction;
}
