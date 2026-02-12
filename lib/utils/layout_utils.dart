/// Layout utility functions for responsive design

/// Tablet width tiers for responsive layout
/// Each tier defines a max screen width and corresponding content width
final List<Map<String, int>> tabletWidthTier = [
  {'max': 890, 'width': -1},
  {'max': 1280, 'width': 890 - 250},
  {'max': 999999, 'width': 1030 - 250},
];

/// Calculate appropriate tablet content width based on screen width
/// Returns -1 for mobile layouts, or the constrained width for tablet/desktop
int calculateTabletWidth(int screenWidth) {
  for (var tier in tabletWidthTier) {
    if (screenWidth <= tier['max']!) {
      return tier['width']!;
    }
  }
  return tabletWidthTier.last['width']!;
}
