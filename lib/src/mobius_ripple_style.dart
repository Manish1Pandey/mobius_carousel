/// Style of the drag-down ripple indicator drawn behind the cards while
/// the user pulls the center card downward.
enum MobiusRippleStyle {
  /// Stacked sine-wave horizontal bands rising from the bottom (default).
  wavy,

  /// Concentric full circular rings emanating from a focal point near the
  /// bottom-center of the screen.
  circular,

  /// Concentric upper-half arches bowing upward from the bottom edge.
  semiCircle,

  /// No ripple indicator at all.
  none,
}
