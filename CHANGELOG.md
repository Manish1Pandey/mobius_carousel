## 0.2.0

* `MobiusCarousel.cardBuilder` — optional builder for fully custom card
  visuals. The carousel keeps handling tilt, scale, gestures, ripple,
  confetti, dialog, and auto-play around whatever widget you return.
* `MobiusItem.data` (`Object?`) — attach any payload (domain model,
  analytics id, callback, map) and cast it back inside `cardBuilder`.
* `MobiusItem.child` (`Widget?`) — per-item custom widget that overrides
  both the built-in card and `cardBuilder` for that specific slot.

## 0.1.0

* Initial release.
* Infinite-wrap horizontal swipe carousel with tilted neighbor cards.
* Auto-play that pauses during user interaction.
* Per-side configuration for tilt angle, position offset, and gap.
* Rubber-band pull-down on the center card with elastic snap-back.
* `onOfferClaimed` callback when the user pulls past `claimThreshold`.
* Optional built-in confetti burst on claim (carousel + dialog).
* Optional built-in non-dismissable "Offer Claimed!" dialog.
* `onClaimConfirmed` callback for custom routing on "Awesome!" tap.
* Four ripple styles for the drop indicator: `wavy`, `circular`,
  `semiCircle`, `none`.
* Scallop-edged ticket card shape with dashed code chip.
* Header / footer slots for fully custom top/bottom widgets.
* Zero third-party dependencies — uses only the Flutter SDK.
