import 'package:flutter/material.dart';

/// A single card rendered by [MobiusCarousel].
///
/// All fields are optional so consumers can supply only what they have for
/// a given offer; missing fields render as empty strings or sensible
/// defaults inside the built-in ticket card.
@immutable
class MobiusItem {
  /// Promo / coupon code shown in the dashed chip at the top of the card.
  final String? code;

  /// Provider / brand name shown in large text below the logo.
  final String? provider;

  /// Account or reference number shown below the provider.
  final String? accountNumber;

  /// Bill / offer amount shown at the bottom of the card.
  final String? billAmount;

  /// Icon shown inside the circular logo badge.
  final IconData? logo;

  /// Accent color used for the code chip, badge, bill-amount label, shadow
  /// glow, dialog button, and ripple indicator while this card is focused.
  final Color? color;

  /// Arbitrary payload attached to this item. The built-in card ignores
  /// it; a custom `cardBuilder` or [child] can cast it to whatever type
  /// the consumer stored. Useful when the consumer needs extra fields
  /// beyond the predefined ones — e.g. a domain model, an analytics id,
  /// a callback, or a `Map<String, dynamic>` of arbitrary attributes.
  ///
  /// ```dart
  /// MobiusItem(
  ///   provider: 'X',
  ///   data: MyOffer(id: 42, tier: 'gold', validUntil: ...),
  /// )
  /// // inside cardBuilder:
  /// final offer = item.data as MyOffer;
  /// ```
  final Object? data;

  /// Per-item custom widget that completely replaces the built-in card
  /// visual for this slot. When non-null, it takes precedence over both
  /// the built-in card and the carousel-level `cardBuilder`. The carousel
  /// still sizes it to `cardWidth × cardHeight` and wraps it in the tap
  /// handler, so drag / claim / confetti / dialog continue to work.
  ///
  /// ```dart
  /// MobiusItem(
  ///   provider: 'X',
  ///   child: MyCustomOfferCard(...),
  /// )
  /// ```
  ///
  /// Priority order for each card's content:
  /// 1. `item.child` (per-item override)
  /// 2. carousel-level `cardBuilder`
  /// 3. built-in scallop ticket card
  final Widget? child;

  /// Creates a [MobiusItem].
  const MobiusItem({
    this.code,
    this.provider,
    this.accountNumber,
    this.billAmount,
    this.logo,
    this.color,
    this.data,
    this.child,
  });
}
