enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  bool get isTop => this == topLeft || this == topCenter || this == topRight;
  bool get isBottom => this == bottomLeft || this == bottomCenter || this == bottomRight;
  bool get isLeft => this == topLeft || this == centerLeft || this == bottomLeft;
  bool get isRight => this == topRight || this == centerRight || this == bottomRight;
  bool get isCenter => this == topCenter || this == bottomCenter || this == centerLeft || this == centerRight;

  bool get isCorner => !isCenter;
  bool get isEdge => isCenter;
}
