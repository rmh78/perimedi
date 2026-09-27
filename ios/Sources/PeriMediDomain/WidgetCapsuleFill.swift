import Foundation

public enum WidgetCapsuleFill {
    public static let minimumContrast = 4.5

    public static func hex(_ medicationHex: String) -> String {
        guard var rgb = components(medicationHex) else { return medicationHex }
        var steps = 0
        while contrastWithWhite(rgb) < minimumContrast && steps < 24 {
            rgb = (rgb.0 * 0.92, rgb.1 * 0.92, rgb.2 * 0.92)
            steps += 1
        }
        return String(format: "#%02x%02x%02x", Int(rgb.0.rounded()), Int(rgb.1.rounded()), Int(rgb.2.rounded()))
    }

    public static func contrastWithWhite(_ hex: String) -> Double? {
        guard let rgb = components(hex) else { return nil }
        return contrastWithWhite(rgb)
    }

    private static func components(_ hex: String) -> (Double, Double, Double)? {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard raw.count == 6, let value = Int(raw, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xff),
            Double((value >> 8) & 0xff),
            Double(value & 0xff)
        )
    }

    private static func contrastWithWhite(_ rgb: (Double, Double, Double)) -> Double {
        let lum = 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
        return 1.05 / (lum + 0.05)
    }

    private static func linear(_ channel: Double) -> Double {
        let s = channel / 255
        if s <= 0.04045 { return s / 12.92 }
        return pow((s + 0.055) / 1.055, 2.4)
    }
}
