import SwiftData
import SwiftUI

/// The Settings sheet (013): export-everything, the blank templates, the
/// iCloud row, Delete All for each list, and About — reached from both
/// lists' "…" menu, presented as a sheet, with the form sheets' chrome.
///
/// Built from the detail screens' vocabulary — `DetailSection` headings,
/// hairline-ruled rows, brass actions, rust for the two destructive rows —
/// rather than a system list: a Trove screen, not the iOS Settings app in
/// a dark theme. Everything it shows comes from `SettingsViewModel`; the
/// view decides only layout.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// The presenting list view threads `syncMonitor`, the storage mode and
    /// the fallback reason in — the way `ContentView` threads them into
    /// every screen — so the sheet never reads an observable from the
    /// environment it might not have.
    init(
        modelContext: ModelContext,
        syncMonitor: SyncMonitor = .notSyncing,
        storageMode: StorageMode = .cloudKit,
        storageFallbackReason: String? = nil
    ) {
        _viewModel = State(
            initialValue: SettingsViewModel(
                modelContext: modelContext,
                syncMonitor: syncMonitor,
                storageMode: storageMode,
                storageFallbackReason: storageFallbackReason
            )
        )
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                    exportSection
                    templatesSection
                    marketSection
                    iCloudSection
                    deleteSection
                    aboutSection
                }
                .padding(.horizontal, theme.metrics.screenGutter)
                .padding(.top, theme.metrics.sectionGap)
                .padding(.bottom, theme.metrics.sectionGap)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Never disabled (spec P4): leaving mid-export abandons the
            // sheet's state, and a delete completes regardless.
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(theme.colors.accentBrass)
            }
        }
        .onAppear(perform: viewModel.load)
        // The share sheet presents over Settings and returns to it. One
        // sheet for one file or two — `StagedExport` is a set since T002.
        .sheet(item: $viewModel.stagedExport) { staged in
            ShareSheet(urls: staged.urls)
                .presentationDetents([.medium, .large])
        }
        // One alert off one optional (012's lesson), switching on the
        // case. The confirm button calls the intent *plainly*: the binding
        // below writes `alert` nil on any tap before a spawned task would
        // run, and the intent takes its target as a parameter for exactly
        // that reason (T017).
        .alert(
            viewModel.alertTitle,
            isPresented: Binding(
                get: { viewModel.alert != nil },
                set: { if !$0 { viewModel.alert = nil } }
            ),
            presenting: viewModel.alert
        ) { alert in
            switch alert {
            case .confirmDelete(let target, _):
                Button(DeleteAllCopy.confirm, role: .destructive) {
                    viewModel.confirmDeleteAll(target)
                }
                Button(DeleteAllCopy.cancel, role: .cancel) {
                    viewModel.cancelDeleteAll()
                }
            case .deleteFailed, .exportFailed:
                Button("OK", role: .cancel) {}
            }
        } message: { _ in
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - Sections, in spec order

    private var exportSection: some View {
        DetailSection(title: "Export") {
            VStack(spacing: 0) {
                SettingsActionRow(
                    title: "Export All as CSV…",
                    isActing: viewModel.activity == .exportCSV,
                    isEnabled: viewModel.canExportEverything && !viewModel.isBusy
                ) {
                    Task { await viewModel.exportEverythingAsCSV() }
                }
                SettingsActionRow(
                    title: "Export All as PDF…",
                    isActing: viewModel.activity == .exportPDF,
                    isEnabled: viewModel.canExportEverything && !viewModel.isBusy
                ) {
                    Task { await viewModel.exportEverythingAsPDF() }
                }
            }
        }
    }

    private var templatesSection: some View {
        DetailSection(title: "Templates") {
            VStack(spacing: 0) {
                SettingsActionRow(
                    title: "Items Template…",
                    isActing: viewModel.activity == .itemsTemplate,
                    isEnabled: !viewModel.isBusy
                ) {
                    Task { await viewModel.exportItemsTemplate() }
                }
                SettingsActionRow(
                    title: "Wishlist Template…",
                    isActing: viewModel.activity == .wishlistTemplate,
                    isEnabled: !viewModel.isBusy
                ) {
                    Task { await viewModel.exportWishlistTemplate() }
                }
            }
        }
    }

    /// 002: one row that walks every matched item, with the walk's position
    /// beside it and, when it stops early, one line saying why (Q12 — a
    /// status line, never an alert: Settings presents exactly one alert, and
    /// it belongs to Delete All).
    private var marketSection: some View {
        DetailSection(title: MarketCopy.settingsSectionTitle) {
            VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                SettingsActionRow(
                    title: MarketCopy.refreshAll,
                    isActing: viewModel.activity == .refreshMarket,
                    isEnabled: viewModel.canRefreshMarketValues && !viewModel.isBusy,
                    detail: viewModel.marketRefreshProgress.map {
                        MarketCopy.progress(done: $0.done, total: $0.total)
                    }
                ) {
                    Task { await viewModel.refreshMarketValues() }
                }
                .accessibilityIdentifier("settings.refreshMarket")
                // Every status this screen shows is a stopped walk, so the
                // line is always the failure colour — the delete footer's
                // shape, in rust.
                if let status = viewModel.marketRefreshStatus {
                    Text(status)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.colors.accentRustText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Decision 38: a walk that found nothing due says so — the
                // same line shape, in the quiet colour, since nothing failed.
                if let note = viewModel.marketRefreshNote {
                    Text(note)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.colors.textQuiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.refreshMarket.note")
                }
            }
        }
    }

    /// Read-only and live: the view model reads the monitor's phase, so a
    /// sync finishing changes this without leaving the screen.
    private var iCloudSection: some View {
        DetailSection(title: "iCloud") {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.syncStatus.headline)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(viewModel.syncStatus.detail)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.colors.textQuiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                theme.colors.surfaceInset.frame(height: theme.metrics.hairline)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var deleteSection: some View {
        DetailSection(title: "Delete") {
            VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                VStack(spacing: 0) {
                    SettingsActionRow(
                        title: "Delete All Items…",
                        isActing: viewModel.activity == .deleteItems,
                        isEnabled: viewModel.canDeleteItems && !viewModel.isBusy,
                        isDestructive: true,
                        accessibilityHint: "Permanently deletes every item in your library."
                    ) {
                        viewModel.requestDeleteAll(.items)
                    }
                    SettingsActionRow(
                        title: "Delete All Wishlist Items…",
                        isActing: viewModel.activity == .deleteWishlist,
                        isEnabled: viewModel.canDeleteWishlist && !viewModel.isBusy,
                        isDestructive: true,
                        accessibilityHint: "Permanently deletes every item on your wishlist."
                    ) {
                        viewModel.requestDeleteAll(.wishlist)
                    }
                }
                // The mitigation sits on the same screen, and says so.
                Text(DeleteAllCopy.footer)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.colors.textQuiet)
            }
        }
    }

    private var aboutSection: some View {
        DetailSection(title: "About") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trove")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Your Gear, Valued.")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.colors.textQuiet)
                Text(viewModel.versionLine)
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.colors.textMonoMeta)
                    .padding(.top, 4)
                // 002 (Decisions 12, 13, 18, 25): Reverb's attribution
                // verbatim, the contact address, and the policy the notice
                // links to — every string and both destinations from
                // `MarketCopy`, so nothing here is typed twice.
                Text(MarketCopy.attribution)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.colors.textQuiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                Link(MarketCopy.contactAddress, destination: MarketCopy.contactURL)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.accentBrass)
                    .padding(.top, 8)
                    .accessibilityIdentifier("about.contact")
                Link(MarketCopy.privacyPolicyTitle, destination: MarketCopy.privacyPolicyURL)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.accentBrass)
                    .padding(.top, 4)
                    .accessibilityIdentifier("about.privacy")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One action row: a hairline-ruled button in brass — rust for the two
/// destructive ones, dimmed when there's nothing to act on — with the
/// compact spinner trailing while it is the acting row.
///
/// The destructive rows carry the role *and* an explicit hint:
/// `ButtonRole.destructive` isn't documented to announce anything outside
/// alerts and menus, and with `.plain` styling it draws nothing either, so
/// criterion 18's "announced as destructive" rests on the hint.
private struct SettingsActionRow: View {
    let title: String
    let isActing: Bool
    let isEnabled: Bool
    /// The acting row's own meta — 002's "3 of 12", in the mono meta the
    /// rest of the app counts in, ahead of the spinner.
    var detail: String?
    var isDestructive = false
    var accessibilityHint: String?
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(role: isDestructive ? .destructive : nil, action: action) {
            HStack(spacing: theme.metrics.cardPadding) {
                Text(title)
                    .font(theme.typography.body)
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.colors.textMonoMeta)
                }
                if isActing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors.accentBrass)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                theme.colors.surfaceInset.frame(height: theme.metrics.hairline)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityHint(accessibilityHint ?? "")
    }

    private var color: Color {
        if !isEnabled && !isActing { return theme.colors.textDisabled }
        return isDestructive ? theme.colors.accentRustText : theme.colors.accentBrass
    }
}

// MARK: - Previews

@MainActor
private func previewContainer(populated: Bool) -> ModelContainer {
    let configuration = ModelConfiguration(schema: TroveSchema.combinedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: TroveSchema.combinedSchema, configurations: configuration)
    if populated {
        let context = container.mainContext
        context.insert(Item(name: "Telecaster", categoryPath: "Music/Guitars", purchasePriceCents: 1_200_00, currentValueCents: 1_450_00))
        context.insert(Item(name: "Deluxe Amp", categoryPath: "Music/Amps", purchasePriceCents: 900_00))
        context.insert(WishlistItem(name: "Pedal Steel", categoryPath: "Music/Guitars", estimatedCostCents: 2_500_00))
        try? context.save()
    }
    return container
}

#Preview("Populated, syncing") {
    let container = previewContainer(populated: true)
    NavigationStack {
        SettingsView(modelContext: container.mainContext, storageMode: .cloudKit)
    }
    .modelContainer(container)
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    let container = previewContainer(populated: false)
    NavigationStack {
        SettingsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

#Preview("Local-only fallback") {
    let container = previewContainer(populated: true)
    NavigationStack {
        SettingsView(
            modelContext: container.mainContext,
            storageMode: .localOnly,
            storageFallbackReason: "The operation couldn't be completed. (CKErrorDomain error 1.)"
        )
    }
    .modelContainer(container)
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
