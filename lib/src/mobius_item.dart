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

  /// Creates a [MobiusItem].
  const MobiusItem({
    this.code,
    this.provider,
    this.accountNumber,
    this.billAmount,
    this.logo,
    this.color,
  });
}
