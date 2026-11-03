import CoreGraphics

struct ScreenFraction: Equatable {
    var dx: CGFloat
    var dy: CGFloat
}

enum IconLongPress: Equatable {
    case at(ScreenFraction)
    case element
    case skip
}

enum IconLongPressPlan {
    static func decide(frame: CGRect, screen: CGRect, elementExists: Bool) -> IconLongPress {
        _ = elementExists
        let dx = (frame.midX - screen.minX) / screen.width
        let dy = (frame.midY - screen.minY) / screen.height
        let placed = frame.width > 8 && frame.height > 8
            && screen.width > 8 && screen.height > 8
            && dx.isFinite && dy.isFinite
            && dx > 0 && dy > 0
            && dx <= 1 && dy <= 1
        if placed {
            return .at(ScreenFraction(dx: dx, dy: dy))
        }
        return .element
    }
}

enum RestoreMenu: Equatable {
    case tap
    case missing
}

enum RestoreMenuPlan {
    static func decide(buttonExists: Bool, buttonWidth: CGFloat) -> RestoreMenu {
        _ = buttonExists
        _ = buttonWidth
        return .tap
    }
}

enum RestoreTarget: Equatable {
    case alreadyIcon
    case widget(CGRect)
    case absent
}

enum RestoreTargetPlan {
    static func decide(appIcon: CGRect?, widget: CGRect?) -> RestoreTarget {
        if appIcon != nil { return .alreadyIcon }
        if let widget { return .widget(widget) }
        return .alreadyIcon
    }
}

enum NameFieldLookup: Equatable {
    case textField
    case entireHierarchy
}

enum NameFieldLookupPlan {
    static func focusWalk(id: String) -> NameFieldLookup {
        if id.hasSuffix(".focused") { return .entireHierarchy }
        return .textField
    }
}
