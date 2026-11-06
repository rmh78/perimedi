import PeriMediDomain
import SwiftUI
import UIKit
import WidgetKit
import PeriDesign

struct DoseWidgetEntry: TimelineEntry {
    var date: Date
    var face: DoseWidgetFace
}

struct DoseWidgetTimeline: TimelineProvider {
    func placeholder(in context: Context) -> DoseWidgetEntry {
        let now = Date()
        return DoseWidgetEntry(date: now, face: DoseWidgetSnapshot.placeholder.face(at: now))
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseWidgetEntry) -> Void) {
        let now = Date()
        completion(DoseWidgetEntry(date: now, face: DoseWidgetSnapshotFile.read().face(at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseWidgetEntry>) -> Void) {
        let snapshot = DoseWidgetSnapshotFile.read()
        let now = Date()
        let midnight = DateKeys.calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)
        let faceNow = snapshot.face(at: now)
        var entries = [DoseWidgetEntry(date: now, face: faceNow)]
        if faceNow.showsCheck, let until = snapshot.ack?.until, until > now {
            entries.append(DoseWidgetEntry(date: until, face: snapshot.face(at: until)))
            if midnight > until {
                entries.append(DoseWidgetEntry(date: midnight, face: snapshot.face(at: midnight)))
            }
            entries.sort { $0.date < $1.date }
            completion(Timeline(entries: entries, policy: .after(until)))
            return
        }
        if midnight > now {
            entries.append(DoseWidgetEntry(date: midnight, face: snapshot.face(at: midnight)))
        }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

struct DoseWidgetView: View {
    var face: DoseWidgetFace
    var entryDate: Date
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 2 : 4) {
            Text(face.brandTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(PeriColor.blush800)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            if let helper = face.helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(PeriColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .opacity(face.helperBlank ? 0 : 1)
                    .accessibilityHidden(face.helperBlank)
            }
            if face.rows.isEmpty {
                if let emptyTitle = face.emptyTitle {
                    Text(emptyTitle)
                        .font(.subheadline)
                        .foregroundStyle(PeriColor.ink)
                }
            } else if family == .systemMedium {
                mediumList(face.rows)
            } else {
                smallStack(face.rows)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack {
                PeriColor.cream
                RadialGradient(
                    colors: [PeriColor.pageWash, .clear],
                    center: UnitPoint(x: 0.1, y: 0),
                    startRadius: 4,
                    endRadius: 180
                )
            }
        }
    }

    private func smallStack(_ rows: [DoseWidgetFace.Row]) -> some View {
        let front = rows[0]
        let extra = rows.count - 1
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                medIcon(front)
                VStack(alignment: .leading, spacing: 0) {
                    Text(front.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PeriColor.ink)
                        .lineLimit(1)
                    Text(front.detail)
                        .font(.caption)
                        .foregroundStyle(PeriColor.inkSoft)
                        .lineLimit(1)
                }
            }
            control(for: front)
            if extra > 0 {
                Text("+\(extra)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PeriColor.blush800)
            }
        }
    }

    private func mediumList(_ rows: [DoseWidgetFace.Row]) -> some View {
        let shown = Array(rows.prefix(2))
        let extra = rows.count - 2
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(shown) { row in
                medRow(row)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PeriColor.blush800)
            }
        }
    }

    private func medRow(_ row: DoseWidgetFace.Row) -> some View {
        HStack(spacing: 8) {
            medIcon(row)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PeriColor.ink)
                    .lineLimit(1)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(PeriColor.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            control(for: row)
        }
    }

    private func medIcon(_ row: DoseWidgetFace.Row) -> some View {
        let ring = medColor(row.color) ?? PeriColor.blush500
        return formImage(row.icon)
            .scaledToFill()
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .padding(2)
            .background(Circle().fill(ring))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func formImage(_ name: String) -> some View {
        if #available(iOS 18.0, *) {
            Image(uiImage: formThumbnail(name))
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
        } else {
            Image(uiImage: formThumbnail(name))
                .resizable()
        }
    }

    private func formThumbnail(_ name: String) -> UIImage {
        // The catalog photo is 1024px. The small widget archive rejects that size.
        let side: CGFloat = 96
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            UIImage(named: name)?.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    @ViewBuilder
    private func control(for row: DoseWidgetFace.Row) -> some View {
        switch row.control {
        case .take:
            TakeControl(row: row, actionLabel: face.actionLabel, entryDate: entryDate)
        case .check:
            doseCapsule("✓", widthOf: face.actionLabel, color: row.color)
        }
    }
}

struct PeriMediDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DoseWidgetKind.id, provider: DoseWidgetTimeline()) { entry in
            DoseWidgetView(face: entry.face, entryDate: entry.date)
        }
        .configurationDisplayName(LocalizedStringResource("widget.gallery.name", defaultValue: "PeriMedi"))
        .description(LocalizedStringResource("widget.gallery.description", defaultValue: "Today's medications"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PeriMediDoseWidgetBundle: WidgetBundle {
    var body: some Widget {
        PeriMediDoseWidget()
    }
}

private func doseCapsule(_ text: String, widthOf match: String, color: String) -> some View {
    let sizing = match.isEmpty ? text : match
    return ZStack {
        Text(sizing)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .hidden()
            .accessibilityHidden(true)
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Capsule().fill(medColor(WidgetCapsuleFill.hex(color)) ?? PeriColor.blush500))
}

private struct TakeControl: View {
    var row: DoseWidgetFace.Row
    var actionLabel: String
    var entryDate: Date
    @State private var tapped = false

    var body: some View {
        let glyph = TakeGlyph.merged(control: row.control, tapped: tapped)
        ZStack {
            if case .take(let label) = row.control {
                Button(intent: MarkTodayMedicationTakenIntent(medicationId: row.medicationId)) {
                    doseCapsule(label, widthOf: actionLabel, color: row.color)
                }
                .buttonStyle(LatchCheckStyle(tapped: $tapped))
                .opacity(glyph == .check ? 0 : 1)
                .accessibilityHidden(glyph == .check)
            }
            if glyph == .check {
                doseCapsule("✓", widthOf: actionLabel, color: row.color)
                    .contentShape(Capsule())
            }
        }
        .onChange(of: entryDate) { _, _ in
            if case .take = row.control {
                tapped = false
            }
        }
    }
}

private struct LatchCheckStyle: ButtonStyle {
    @Binding var tapped: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { tapped = true }
            }
    }
}

private enum TakeGlyph: Equatable {
    case take(String)
    case check

    static func merged(control: DoseWidgetControl, tapped: Bool) -> TakeGlyph {
        switch control {
        case .check:
            return .check
        case .take(let label):
            return tapped ? .check : .take(label)
        }
    }
}

private func medColor(_ hex: String) -> Color? {
    var body = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if body.hasPrefix("#") {
        body.removeFirst()
    }
    guard body.count == 6, UInt64(body, radix: 16) != nil else { return nil }
    return Color(hex: hex)
}
