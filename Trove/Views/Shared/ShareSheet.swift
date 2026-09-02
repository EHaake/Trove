import SwiftUI
import UIKit

/// The system share sheet for a staged export — one file, or the several
/// 013's export-everything hands it together.
///
/// **Flagged UIKit exception**, per CLAUDE.md — the constitution's first
/// sanctioned shape verbatim: a `UIViewControllerRepresentable` wrapper,
/// confined to this file, zero logic. SwiftUI's own `ShareLink` can't be
/// presented from view-model state (it generates on its own tap, which
/// plan.md's Delivery section rejects for burying a testable intent in a
/// view-layer closure with a silent failure mode), and `.fileExporter` is
/// Files-only where the spec requires AirDrop/Mail/anything the sheet
/// offers. This wrapper and `Image(imageData:)` are the app's only UIKit;
/// the PDF renderer has none.
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
