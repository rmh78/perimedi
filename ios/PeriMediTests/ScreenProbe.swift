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
        let dx = (frame.midX - screen.minX) / screen.width
        let dy = (frame.midY - screen.minY) / screen.height
        let finite = dx.isFinite && dy.isFinite && dx > 0 && dy > 0 && dx <= 1 && dy <= 1
        let sized = frame.width > 8 && frame.height > 8
            && screen.width > 8 && screen.height > 8
        let inset = min(
            frame.midX - screen.minX,
            frame.midY - screen.minY,
            screen.maxX - frame.midX,
            screen.maxY - frame.midY
        )
        if sized && finite && inset >= 24 {
            return .at(ScreenFraction(dx: dx, dy: dy))
        }
        if elementExists && sized && inset >= 24 {
            return .element
        }
        return .skip
    }
}

enum RestoreMenu: Equatable {
    case tap
    case missing
}

enum RestoreMenuPlan {
    static func decide(buttonExists: Bool, buttonWidth: CGFloat) -> RestoreMenu {
        if buttonExists && buttonWidth > 8 { return .tap }
        return .missing
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
        return .absent
    }
}

enum NameFieldLookup: Equatable {
    case textField
    case focusFlag
    case entireHierarchy
}

enum NameFieldLookupPlan {
    static func focusWalk(id: String) -> NameFieldLookup {
        if id.hasSuffix(".focused") {
            return .focusFlag
        }
        return .textField
    }
}
