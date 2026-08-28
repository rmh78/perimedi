import SwiftUI
import PeriMediDomain

struct CycleView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store

    @StateObject private var plotScroll = PlotScrollHandle()

    private let dayMin: CGFloat = 22
    private let labelCol: CGFloat = 166
    private let labelLeading: CGFloat = 10
    private let stripH: CGFloat = 46
    private let laneH: CGFloat = 44
    private let laneGap: CGFloat = 12
    private let laneBottomPad: CGFloat = 12
    private let cellInset: CGFloat = 1.5
    private let cellInsetY: CGFloat = 3

    var body: some View {
        let snap = CycleSnapshot.build(
            selectedDate: app.selectedDate,
            today: DateKeys.todayKey(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            remarks: store.remarks,
            symptomScores: store.symptomScores,
            periods: store.periods,
            settings: store.settings
        )
        ScrollView {
            VStack(spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        pager(snap)
                        medsTitleRow
                        miniLegend
                        chart(snap)
                        if snap.hasDayBadges {
                            symptomChips(snap)
                        }
                    }
                    .padding(12)
                }
                if store.medications.isEmpty && store.periods.isEmpty {
                    introCard
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            switch app.launchSheet {
            case "med": app.medSheet = MedSheetState(isNew: true, medication: nil)
            case "period": app.showPeriod = true
            case "symptom": app.showSymptom = true
            default: break
            }
            app.launchSheet = nil
        }
    }

    private func pager(_ snap: CycleSnapshot) -> some View {
        HStack(spacing: 4) {
            PillButton(title: app.t("common.today"), kind: .secondary, identifier: A11yID.pagerToday) {
                app.goToToday()
                plotScroll.centerDay(snap.days.firstIndex(of: snap.today) ?? snap.selectedIndex)
            }
            chevron("left", app.t("diagram.prevDay"), false) { page(snap, -1) }
            chevron("right", app.t("diagram.nextDay"), false) { page(snap, 1) }
            Text(pagerLabel(snap))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityIdentifier(A11yID.pagerLabel)
                .accessibilityValue(pagerLabel(snap))
            Spacer(minLength: 0)
        }
    }

    private func chevron(_ dir: String, _ label: String, _ disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.\(dir)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blush700)
                .frame(width: 36, height: 36)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
        .accessibilityIdentifier(dir == "left" ? A11yID.pagerPrev : A11yID.pagerNext)
        .buttonStyle(.plain)
    }

    private func symptomChips(_ snap: CycleSnapshot) -> some View {
        let info = snap.selectedInfo
        let notes = snap.selectedNotes
        let scores = snap.selectedScores
        return VStack(alignment: .leading, spacing: 6) {
            if info.isLoggedPeriod {
                periodChip(app.t("diagram.periodTitle"), predicted: false, identifier: A11yID.chipPeriod)
            } else if info.isPredictedPeriod {
                periodChip(app.t("diagram.predictedPeriodTitle"), predicted: true)
            }
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(scores, id: \.rowId) { score in
                    Button {
                        app.showSymptom = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.symptom)
                            Text(scoreChipName(score))
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#7a4a00"))
                                .lineLimit(1)
                            Text("·")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "#c4a24e"))
                            Text(scoreChipWord(score))
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#7a4a00"))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: "#fff6e0")))
                        .overlay(Capsule().stroke(Color(hex: "#f0dc9a"), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(scoreChipName(score)), \(scoreChipWord(score))")
                    .accessibilityIdentifier(A11yID.chipScore(score.id))
                }
                ForEach(notes.filter { note in
                    !scores.contains { $0.note == note.body }
                }) { note in
                    Button {
                        app.showSymptom = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.symptom)
                            Text(note.body)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#7a4a00"))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: "#fff6e0")))
                        .overlay(Capsule().stroke(Color(hex: "#f0dc9a"), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(note.body)
                }
            }
        }
    }

    private func scoreChipName(_ score: SymptomScore) -> String {
        app.t("symptom.id.\(score.id)")
    }

    private func scoreChipWord(_ score: SymptomScore) -> String {
        let word = app.t("symptom.level.\(score.id).\(score.severity)")
        return word == "symptom.level.\(score.id).\(score.severity)" ? "\(score.severity)" : word
    }
