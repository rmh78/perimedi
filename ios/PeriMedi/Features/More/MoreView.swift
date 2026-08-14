import SwiftUI
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
    @State private var confirm: ConfirmAction?

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
                                    filled: locale.language == lang
                                ) {
                                    locale.language = lang
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            label: app.t("more.sampleLabel")
                        ) {
                            confirm = ConfirmAction(message: app.t("more.sampleConfirm")) {
                                do {
                                    try store.loadSample()
                                    status = app.t("more.sampleLoaded")
                                    error = nil
                                } catch {
                                    self.error = app.t("more.importFailed")
                                }
                            }
                        }
                        divider
                        backupRow(title: app.t("more.exportTitle"), body: app.t("more.exportBody"), label: app.t("more.exportLabel")) {
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
                        backupRow(title: app.t("more.importTitle"), body: app.t("more.importBody"), label: app.t("more.importLabel")) {
                            showImporter = true
                        }
                        divider
                        backupRow(title: app.t("more.clearTitle"), body: app.t("more.clearBody"), label: app.t("more.clearLabel"), destructive: true) {
                            confirm = ConfirmAction(message: app.t("more.clearConfirm")) {
                                store.clearAll()
                                status = app.t("more.cleared")
                                error = nil
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                Text(app.t("more.disclaimer"))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.horizontal, 6)
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure: error = app.t("more.importFailed")
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .confirmationDialog(app.t("confirm.title"), isPresented: Binding(
            get: { confirm != nil },
            set: { if !$0 { confirm = nil } }
        ), titleVisibility: .visible) {
            Button(app.t("confirm.title"), role: .destructive) {
                confirm?.action()
                confirm = nil
            }
            Button(app.t("common.cancel"), role: .cancel) { confirm = nil }
        } message: {
            Text(confirm?.message ?? "")
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

    private func backupRow(title: String, body: String, label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(body).font(.caption).foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(destructive ? Theme.blush700 : Theme.blush700)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .overlay(Capsule().stroke(destructive ? Theme.blush300 : Theme.blush300, lineWidth: 1))
            }
            .buttonStyle(.plain)
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
        } catch {
            self.error = app.t("more.importFailed")
        }
    }
}

private struct ConfirmAction {
    var message: String
    var action: () -> Void
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
