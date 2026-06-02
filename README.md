# mobius_carousel

A custom infinite carousel slider for Flutter with tilted neighbor cards, rubber-band pull-to-claim, a confetti burst, a non-dismissable claim dialog, and a configurable drop ripple.

Built from scratch — **zero third-party dependencies**, no state-management library required.

## Features

- 🎠 **Infinite-wrap horizontal swipe** through any list of items
- ▶️ **Auto-play** with smooth easing; pauses on user interaction
- 🃏 **Tilted neighbor cards** that fan around the center — per-side tilt angle and offset
- 💧 **Rubber-band pull-down** on the center card with elastic snap-back
- 🎯 **Pull-to-claim** — fires a callback when the user drags past a threshold
- 🎉 **Confetti burst** that plays on the carousel *and* on the dialog
- 🪟 **Non-dismissable claim dialog** with elastic entry animation
- 🧭 **`onClaimConfirmed` callback** for custom routing on the dialog's "Awesome!" tap
- 🌊 **Four ripple styles** for the drop indicator: `wavy`, `circular`, `semiCircle`, `none`
- 🎫 **Scallop-edged ticket card** with dashed code chip — fully styled internally
- 🪧 **Header / footer slots** for any widget above and below the carousel

## Install

```yaml
dependencies:
  mobius_carousel: ^0.1.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:mobius_carousel/mobius_carousel.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobiusCarousel(
      items: const [
        MobiusItem(
          code: 'AQUA20',
          provider: 'Aquaflow Co.',
          accountNumber: '#100000000001',
          billAmount: '₹1,420',
          logo: Icons.water_drop,
          color: Color(0xFF2D67E0),
        ),
        MobiusItem(
          code: 'VOLT24',
          provider: 'Voltline Power',
          accountNumber: '#100000000002',
          billAmount: '₹30,200',
          logo: Icons.electric_bolt,
          color: Color(0xFFE91E63),
        ),
      ],
      onCenterCardTap: (item) => debugPrint('tapped ${item.provider}'),
      onOfferClaimed: (item) => debugPrint('claimed ${item.provider}'),
      onClaimConfirmed: (context, item) {
        Navigator.of(context).pushNamed('/offer', arguments: item);
      },
    );
  }
}
```

## Customization

Every visual is configurable. Defaults reproduce the look in the demo.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `items` | — (required) | List of `MobiusItem`s to render. |
| `header` | `null` | Widget rendered above the carousel. |
| `footer` | `null` | Widget rendered below the carousel. |
| `cardWidth` | `180` | Card width in logical pixels. |
| `cardHeight` | `290` | Card height in logical pixels. |
| `sideCardGap` | `80` | Pixel gap between center card and side cards. |
| `leftCardTiltDegrees` | `23` | Inward tilt of the left neighbor (positive = top leans toward center). |
| `rightCardTiltDegrees` | `23` | Inward tilt of the right neighbor. |
| `leftCardOffset` | `Offset(0, -80)` | Extra position offset for the left neighbor. |
| `rightCardOffset` | `Offset(0, -80)` | Extra position offset for the right neighbor. |
| `initialIndex` | `1` | Which item is centered on first build. |
| `backgroundColor` | `null` | Scaffold background color. |
| `autoPlayInterval` | `Duration(seconds: 4)` | Time between auto-advances. Pass `null` to disable. |
| `claimThreshold` | `120` | Pull distance in pixels required to claim the offer. |
| `showConfetti` | `true` | Whether to play the built-in confetti burst on claim. |
| `showClaimedDialog` | `true` | Whether to show the built-in "Offer Claimed!" dialog on claim. |
| `rippleStyle` | `MobiusRippleStyle.wavy` | `wavy`, `circular`, `semiCircle`, or `none`. |
| `cardBuilder` | `null` | Optional builder for fully custom card visuals. See [Custom card](#custom-card) below. |
| `onCenterCardTap` | `null` | Called when the focused card is tapped. |
| `onOfferClaimed` | `null` | Called once when the pull crosses `claimThreshold`. |
| `onClaimConfirmed` | `null` | Called after the user taps "Awesome!" in the dialog. |

## `MobiusItem`

All fields on the data class are **optional** so consumers can supply only what they have:

```dart
class MobiusItem {
  final String? code;
  final String? provider;
  final String? accountNumber;
  final String? billAmount;
  final IconData? logo;
  final Color? color;
  final Object? data;     // any payload — cast it back in your builder
  final Widget? child;    // per-item custom widget; overrides cardBuilder
}
```

Missing display fields render as empty / use sensible defaults.

### Attaching arbitrary data with `data`

When you need fields beyond the predefined six, store any object on `data` and cast it back inside `cardBuilder`:

```dart
MobiusItem(
  provider: 'Aquaflow',
  data: MyOffer(rewardId: 42, tier: 'gold', expiresAt: DateTime(2025, 12, 31)),
)

// in MobiusCarousel:
cardBuilder: (context, item, isFocused) {
  final offer = item.data! as MyOffer;
  return MyCard(reward: offer.rewardId, tier: offer.tier);
}
```

### Per-item custom widget with `child`

If a specific item needs a completely different visual (e.g. one promo card, the rest are regular), set `child` on just that item:

```dart
items: [
  MobiusItem(provider: 'X', billAmount: '\$1'),      // built-in card
  MobiusItem(
    provider: 'Featured',
    child: SpecialFeatureCard(),                     // custom widget
  ),
  MobiusItem(provider: 'Y', billAmount: '\$2'),      // built-in card
]
```

**Priority** for each card's content:
1. `item.child` — per-item override
2. carousel-level `cardBuilder` — wide override
3. Built-in scallop ticket card — default

## Ripple styles

```dart
MobiusCarousel(
  items: items,
  rippleStyle: MobiusRippleStyle.wavy,        // stacked sine bands  (default)
  // rippleStyle: MobiusRippleStyle.circular,    // concentric rings
  // rippleStyle: MobiusRippleStyle.semiCircle,  // upper-half arches
  // rippleStyle: MobiusRippleStyle.none,        // off
)
```

The ripple's intensity, count, and color tracks the user's vertical drag — pulling deeper reveals more rings, with opacity tied to the focused card's color.

## Custom card

The built-in scallop-edged ticket card reads from the `MobiusItem` fields. If you want full visual control — your own card shape, branding, layout — pass a `cardBuilder`. It receives the item and a `isFocused` flag and returns any widget. The carousel still handles sizing, the tap callback, drag, claim, confetti, and dialog around your card.

```dart
MobiusCarousel(
  items: items,
  cardBuilder: (context, item, isFocused) => Container(
    decoration: BoxDecoration(
      color: item.color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isFocused
          ? [BoxShadow(blurRadius: 24, color: Colors.black26)]
          : null,
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(item.provider ?? '', style: TextStyle(color: Colors.white)),
        Text(item.billAmount ?? '', style: TextStyle(color: Colors.white)),
      ],
    ),
  ),
)
```

Your widget will be sized to `cardWidth × cardHeight`. The provided tap handler centers the card or fires `onCenterCardTap` exactly as the default card does. You can keep using the data fields on `MobiusItem`, ignore them entirely, or pass extra info via your own state — whatever fits your use case.

## Custom claim flow

When the user pulls the center card past `claimThreshold`:

1. `onOfferClaimed(item)` fires once.
2. Confetti animation plays (if `showConfetti: true`).
3. After a 350ms beat, the non-dismissable dialog opens (if `showClaimedDialog: true`).
4. On "Awesome!" tap, the dialog pops and `onClaimConfirmed(context, item)` fires for navigation.

To use a fully custom UI:

```dart
MobiusCarousel(
  items: items,
  showConfetti: false,
  showClaimedDialog: false,
  onOfferClaimed: (item) {
    // your own visual / route
  },
)
```

## Example

See `example/lib/main.dart` for a complete demo with a header, footer, and routing on claim.

## License

MIT
