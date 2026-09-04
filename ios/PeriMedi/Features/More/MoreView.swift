import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PeriMediDomain

struct MoreView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var locale: LocaleController

    @State private var status: String?
    @State private var error: String?
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showImporter = false
    @AppStorage(DoseReminderCenter.masterKey) private var remindersOn = true
    @AppStorage(ReminderSound.storageKey) private var reminderSoundRaw = ReminderSound.system.rawValue
    @State private var notifyDenied = false


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(app.t("language.label"))
                        HStack(spacing: 8) {
                            ForEach(AppLanguage.allCases) { lang in
                                PillButton(
                                    title: app.t(lang == .en ? "language.en" : "language.de"),
                                    kind: locale.language == lang ? .primary : .secondary,
                                    identifier: lang == .en ? A11yID.moreLangEn : A11yID.moreLangDe
                                ) {
                                    locale.language = lang
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(app.t("more.reminders"))
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.t("more.reminders"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(app.t("more.remindersBody"))
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkMuted)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $remindersOn)
                                .labelsHidden()
                                .tint(Theme.blush600)
                                .accessibilityIdentifier(A11yID.moreReminders)
                        }
                        HStack(alignment: .center, spacing: 10) {
                            Text(app.t("more.reminderSound"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            HStack(spacing: 8) {
                                Picker("", selection: $reminderSoundRaw) {
                                    ForEach(ReminderSound.allCases) { sound in
                                        Text(app.t(sound.labelKey))
                                            .lineLimit(1)
                                            .tag(sound.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(Theme.ink)
                                .fixedSize(horizontal: true, vertical: false)
                                .accessibilityIdentifier(A11yID.moreReminderSound)
                                Button {
                                    DoseReminderCenter.shared.previewSound(ReminderSound(rawValue: reminderSoundRaw) ?? .system)
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.blush700)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Theme.blush50))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(app.t("more.reminderSoundPreview"))
                                .accessibilityIdentifier(A11yID.moreReminderSoundPreview)
                            }
                        }
                        if remindersOn, notifyDenied {
                            Text(app.t("more.remindersDenied"))
                                .font(.caption)
                                .foregroundStyle(Theme.blush700)
                            PillButton(title: app.t("more.remindersSettings"), kind: .secondary, identifier: A11yID.moreRemindersSettings) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: remindersOn) { _, on in
                    if on {
                        Task {
                            await DoseReminderCenter.shared.requestAuthorizationIfNeeded()
                            notifyDenied = await DoseReminderCenter.shared.authorizationDenied()
                            DoseReminderCenter.shared.refresh()
                        }
                    } else {
                        DoseReminderCenter.shared.refresh()
                    }
                }
                .onChange(of: reminderSoundRaw) { _, _ in
                    DoseReminderCenter.shared.refresh()
                }

                if let status {
                    Text(status).font(.caption).foregroundStyle(Theme.taken).padding(.horizontal, 4)
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(Theme.blush700).padding(.horizontal, 4)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionLabel(app.t("more.tabBackup"))
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 8)
                        backupRow(
                            title: app.t("more.sampleTitle"),
                            body: app.t("more.sampleBody"),
                            label: app.t("more.sampleLabel"),
                            identifier: A11yID.moreSample
                        ) {
                            app.askConfirm(
                                message: app.t("more.sampleConfirm"),
                                confirmLabel: app.t("more.sampleLabel"),
                                destructive: false
                            ) {
                                do {
                                    try store.loadSample()
                                    app.goToToday()
                                    status = app.t("more.sampleLoaded")
                                    error = nil
                                } catch is PersistenceError {
                                    self.error = app.t("persist.saveFailed")
                                } catch {
                                    self.error = app.t("more.importFailed")
                                }
                            }
                        }
                        divider
                        backupRow(title: app.t("more.exportTitle"), body: app.t("more.exportBody"), label: app.t("more.exportLabel"), identifier: A11yID.moreExport) {
                            do {
                                let data = try BackupCodec.encode(store.exportPayload())
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent("perimedi-backup.json")
                                try data.write(to: url, options: .atomic)
                                exportURL = url
                                showShare = true
                                status = app.t("more.exportDone")
                                error = nil
                            } catch {
                                self.error = app.t("more.exportFailed")
                            }
                        }
                        divider
                        backupRow(title: app.t("more.importTitle"), body: app.t("more.importBody"), label: app.t("more.importLabel"), identifier: A11yID.moreImport) {
                            showImporter = true
                        }
                        divider
                        backupRow(title: app.t("more.clearTitle"), body: app.t("more.clearBody"), label: app.t("more.clearLabel"), identifier: A11yID.moreClear, destructive: true) {
                            app.askConfirm(
                                message: app.t("more.clearConfirm"),
                                confirmLabel: app.t("more.clearLabel"),
                                destructive: true
                            ) {
                                do {
                                    try store.clearAll()
                                    status = app.t("more.cleared")
                                    error = nil
                                } catch {
                                    self.error = app.t("persist.saveFailed")
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                Button {
                    if let url = URL(string: "https://rmh78.github.io/perimedi/app-store/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(app.t("more.privacyPolicy"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.blush700)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.morePrivacyPolicy)
                .padding(.horizontal, 6)

                Text(app.t("more.disclaimer"))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.horizontal, 6)
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            Task { notifyDenied = await DoseReminderCenter.shared.authorizationDenied() }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure: error = app.t("more.importFailed")
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.blush100).frame(height: 1).padding(.leading, 14)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkMuted)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func backupRow(title: String, body: String, label: String, identifier: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(body).font(.caption).foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: 8)
            PillButton(title: label, kind: destructive ? .destructive : .secondary, identifier: identifier, action: action)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let payload = try BackupCodec.decode(Data(contentsOf: url))
            try store.replaceAll(with: payload)
            status = app.t("more.importDone")
            error = nil
        } catch is PersistenceError {
            self.error = app.t("persist.saveFailed")
        } catch {
            self.error = app.t("more.importFailed")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
