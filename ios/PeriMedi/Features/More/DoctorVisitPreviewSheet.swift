import PDFKit
import SwiftUI
import UIKit

struct DoctorVisitPreviewSheet: View {
    @EnvironmentObject private var app: AppModel
    let url: URL
    @State private var showShare = false

    var body: some View {
        DialogChrome(
            title: app.t("visit.title"),
            identifier: A11yID.visitPdfPreview,
            onClose: { app.closeDialog() }
        ) {
            PDFKitView(url: url)
                .frame(minHeight: 420, maxHeight: 520)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } footer: {
            HStack {
                Spacer()
                PillButton(
                    title: app.t("visit.share"),
                    kind: .primary,
                    identifier: A11yID.visitPdfShare
                ) {
                    showShare = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [url])
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .white
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
