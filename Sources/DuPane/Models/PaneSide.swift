enum PaneSide: String {
    case left, right

    var other: PaneSide { self == .left ? .right : .left }
    var accessibilityIDPrefix: String { rawValue }
}
