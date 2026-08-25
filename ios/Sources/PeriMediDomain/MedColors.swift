import Foundation

public enum MedColors {
    public static let formDefaults: [MedForm: String] = [
        .PILL: "#d43d6c",
        .CREAM: "#9b6fc9",
        .DROPS: "#5b8fd9",
        .INJECTION: "#c97b3a",
        .OTHER: "#8a6b78",
    ]

    public static let palette: [String] = [
        "#f472b6", "#ec4899", "#e85a84", "#db2777", "#d43d6c",
        "#be185d", "#9b6fc9", "#7c3aed", "#5b8fd9", "#0d9488",
        "#c97b3a", "#64748b",
    ]

    public static func resolve(form: MedForm, color: String?) -> String {
        if let color, color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil {
            return color
        }
        return formDefaults[form] ?? formDefaults[.OTHER]!
    }
}
