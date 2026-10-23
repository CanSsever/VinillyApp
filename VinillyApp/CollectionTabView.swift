//
//  CollectionTabView.swift
//  VinillyApp
//
//  Final merged collection experience.
//  Keeps the repo's scanner, detail view, cover editor, onboarding,
//  manual search, Stats and Hi-Fi implementations intact.
//

import SwiftUI
import SwiftData
import VisionKit

// MARK: - Final Collection Tab

struct CollectionTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vinyl.addedAt, order: .reverse) private var vinyls: [Vinyl]

    var viewModel: CollectionViewModel

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var showOnboarding = false
    @State private var showAddMenu = false
    @State private var showScanner = false
    @State private var showManualSearch = false
    @State private var scannedCode: String?

    @State private var selectedVinylForDetail: Vinyl?
    @State private var selectedVinylToEdit: Vinyl?

    @State private var showFoundAlert = false
    @State private var showNotFoundAlert = false
    @State private var showAlreadyAddedAlert = false

    @State private var lastFoundVinyl: Vinyl?
    @State private var lastFailedBarcode = ""
    @State private var alreadyAddedTitle = ""

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: Grouped Data

    private var recentlyAdded: [Vinyl] {
        Array(vinyls.prefix(10))
    }

    private var artistGroups: [FinalCollectionGroup] {
        Dictionary(grouping: vinyls) { vinyl in
            normalizedGroupValue(vinyl.artist, fallback: "Unknown Artist")
        }
        .map { FinalCollectionGroup(title: $0.key, vinyls: $0.value) }
        .sorted {
            if $0.vinyls.count == $1.vinyls.count {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.vinyls.count > $1.vinyls.count
        }
    }

    private var genreGroups: [FinalCollectionGroup] {
        Dictionary(grouping: vinyls.filter { isKnownMetadata($0.genre) }) {
            normalizedGroupValue($0.genre, fallback: "Unknown")
        }
        .map { FinalCollectionGroup(title: $0.key, vinyls: $0.value) }
        .sorted {
            if $0.vinyls.count == $1.vinyls.count {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.vinyls.count > $1.vinyls.count
        }
    }

    private var yearGroups: [FinalCollectionGroup] {
        Dictionary(grouping: vinyls.filter { isKnownMetadata($0.year) }) {
            normalizedGroupValue($0.year, fallback: "Unknown")
        }
        .map { FinalCollectionGroup(title: $0.key, vinyls: $0.value) }
        .sorted {
            let lhs = Int($0.title) ?? 0
            let rhs = Int($1.title) ?? 0

            if lhs == rhs {
                return $0.title > $1.title
            }
            return lhs > rhs
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vinyls.isEmpty {
                    emptyCollectionView
                } else {
                    collectionContent
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("My Collection")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMenu = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .accessibilityLabel("Add Vinyl")
                }
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
            .sheet(item: $selectedVinylToEdit) { vinyl in
                EditCoverSheet(vinyl: vinyl)
            }
            .sheet(item: $selectedVinylForDetail) { vinyl in
                NavigationStack {
                    VinylDetailView(vinyl: vinyl, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showAddMenu) {
                addMenu
            }
            .sheet(isPresented: $showManualSearch) {
                ManualSearchView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showScanner) {
                scannerScreen
            }
            .onChange(of: scannedCode) { _, newCode in
                guard let code = newCode else { return }
                handleScannedBarcode(code)
                scannedCode = nil
            }
            .alert(
                "Vinyl Found! 🎉",
                isPresented: $showFoundAlert,
                presenting: lastFoundVinyl
            ) { _ in
                Button("Great!", role: .cancel) { }
            } message: { vinyl in
                Text("Added to your collection:\n\"\(vinyl.title)\" by \(vinyl.artist)")
            }
            .alert("Already in Collection", isPresented: $showAlreadyAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\"\(alreadyAddedTitle)\" is already in your collection.")
            }
            .alert("No Results Found", isPresented: $showNotFoundAlert) {
                Button("Search Manually") {
                    showManualSearch = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(
                    "No match found for barcode '\(lastFailedBarcode)' in the offline database.\n\nWould you like to search by title or artist?"
                )
            }
        }
    }

    // MARK: - Main Collection Content

    private var collectionContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(vinyls.count) \(vinyls.count == 1 ? "Record" : "Records")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .foregroundColor(.green)
                        .accessibilityLabel("Offline collection")
                }
                .padding(.horizontal, 20)

                if !recentlyAdded.isEmpty {
                    FinalSectionHeader(
                        title: "Recently Added",
                        subtitle: "Your newest records"
                    )

                    horizontalVinylRow(recentlyAdded)
                }

                if !artistGroups.isEmpty {
                    FinalSectionHeader(
                        title: "Artists",
                        subtitle: "\(artistGroups.count) in your collection"
                    )

                    horizontalGroupRow(
                        groups: artistGroups,
                        systemImage: "music.mic",
                        accent: .blue
                    )
                }

                if !genreGroups.isEmpty {
                    FinalSectionHeader(
                        title: "Genres",
                        subtitle: "\(genreGroups.count) categories"
                    )

                    horizontalGroupRow(
                        groups: genreGroups,
                        systemImage: "guitars.fill",
                        accent: .orange
                    )
                }

                if !yearGroups.isEmpty {
                    FinalSectionHeader(
                        title: "Years",
                        subtitle: "Browse by release year"
                    )

                    horizontalGroupRow(
                        groups: yearGroups,
                        systemImage: "calendar",
                        accent: .purple
                    )
                }

                FinalSectionHeader(
                    title: "All Records",
                    subtitle: "Your complete shelf"
                )

                LazyVGrid(columns: gridColumns, spacing: 22) {
                    ForEach(vinyls) { vinyl in
                        FinalVinylCard(vinyl: vinyl, coverSize: 154)
                            .onTapGesture {
                                selectedVinylForDetail = vinyl
                            }
                            .contextMenu {
                                vinylContextMenu(for: vinyl)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, 8)
        }
    }

    private func horizontalVinylRow(_ records: [Vinyl]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(records) { vinyl in
                    FinalVinylCard(vinyl: vinyl, coverSize: 145)
                        .frame(width: 145)
                        .onTapGesture {
                            selectedVinylForDetail = vinyl
                        }
                        .contextMenu {
                            vinylContextMenu(for: vinyl)
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    private func horizontalGroupRow(
        groups: [FinalCollectionGroup],
        systemImage: String,
        accent: Color
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(groups) { group in
                    NavigationLink {
                        FinalCollectionGroupDetailView(
                            group: group,
                            viewModel: viewModel
                        )
                    } label: {
                        FinalCollectionGroupCard(
                            group: group,
                            systemImage: systemImage,
                            accent: accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func vinylContextMenu(for vinyl: Vinyl) -> some View {
        Button {
            selectedVinylToEdit = vinyl
        } label: {
            Label("Customize Cover", systemImage: "paintbrush.fill")
        }

        Button(role: .destructive) {
            modelContext.delete(vinyl)
            try? modelContext.save()
        } label: {
            Label("Remove from Collection", systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyCollectionView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 132, height: 132)

                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(Color.green.gradient)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }

            Text("Your Collection is Empty")
                .font(.title2.bold())

            Text(
                "Add your first vinyl by scanning its barcode or searching the offline catalog."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 42)

            Button {
                showAddMenu = true
            } label: {
                Label("Add Vinyl", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)

            Spacer()
        }
    }

    // MARK: - Add Flow

    private var addMenu: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Add to Your Collection")
                .font(.headline)

            Text("Choose how to identify your record.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                showAddMenu = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showScanner = true
                }
            } label: {
                Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                showAddMenu = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showManualSearch = true
                }
            } label: {
                Label("Search Manually", systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }

    private var scannerScreen: some View {
        ZStack {
            if DataScannerViewController.isSupported &&
                DataScannerViewController.isAvailable {
                ScannerView(scannedCode: $scannedCode)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)

                    Text("Camera not supported or permission denied.")
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .padding()
            }

            VStack {
                HStack {
                    Spacer()

                    Button {
                        showScanner = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }

                Spacer()
            }
        }
    }

    private func handleScannedBarcode(_ code: String) {
        showScanner = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let found = viewModel.searchByBarcode(code) else {
                lastFailedBarcode = code
                showNotFoundAlert = true
                return
            }

            if vinyls.contains(where: { $0.barcode == found.barcode }) {
                alreadyAddedTitle = found.title
                showAlreadyAddedAlert = true
                return
            }

            modelContext.insert(found)

            do {
                try modelContext.save()
                lastFoundVinyl = found
                showFoundAlert = true
            } catch {
                print("❌ Error while saving in SwiftData: \(error)")
            }
        }
    }

    // MARK: - Metadata Helpers

    private func normalizedGroupValue(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func isKnownMetadata(_ value: String) -> Bool {
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return ![
            "",
            "unknown",
            "n/d",
            "n/a",
            "null",
            "none",
            "0"
        ].contains(lowered)
    }
}

// MARK: - Collection Supporting Models

struct FinalCollectionGroup: Identifiable {
    let title: String
    let vinyls: [Vinyl]

    var id: String {
        title
    }
}

// MARK: - Section Header

struct FinalSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - Vinyl Card

struct FinalVinylCard: View {
    let vinyl: Vinyl
    let coverSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VinylCoverView(vinyl: vinyl, size: coverSize)

            Text(vinyl.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(vinyl.artist)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack(spacing: 5) {
                if known(vinyl.year) {
                    Text(vinyl.year)
                }

                if known(vinyl.year) && known(vinyl.genre) {
                    Text("•")
                }

                if known(vinyl.genre) {
                    Text(vinyl.genre)
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func known(_ value: String) -> Bool {
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return !["", "unknown", "n/d", "n/a", "null", "none", "0"]
            .contains(lowered)
    }
}

// MARK: - Group Card

struct FinalCollectionGroupCard: View {
    let group: FinalCollectionGroup
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(0.12))

                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(accent.gradient)
            }
            .frame(width: 130, height: 90)

            Text(group.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text("\(group.vinyls.count) \(group.vinyls.count == 1 ? "record" : "records")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 130, alignment: .leading)
    }
}

// MARK: - Group Detail

struct FinalCollectionGroupDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let group: FinalCollectionGroup
    var viewModel: CollectionViewModel

    @State private var selectedVinyl: Vinyl?
    @State private var vinylToEdit: Vinyl?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(group.vinyls.count) \(group.vinyls.count == 1 ? "Record" : "Records")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(group.vinyls.sorted(by: sortVinyls)) { vinyl in
                        FinalVinylCard(vinyl: vinyl, coverSize: 154)
                            .onTapGesture {
                                selectedVinyl = vinyl
                            }
                            .contextMenu {
                                Button {
                                    vinylToEdit = vinyl
                                } label: {
                                    Label(
                                        "Customize Cover",
                                        systemImage: "paintbrush.fill"
                                    )
                                }

                                Button(role: .destructive) {
                                    modelContext.delete(vinyl)
                                    try? modelContext.save()
                                } label: {
                                    Label(
                                        "Remove from Collection",
                                        systemImage: "trash"
                                    )
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, 12)
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedVinyl) { vinyl in
            NavigationStack {
                VinylDetailView(vinyl: vinyl, viewModel: viewModel)
            }
        }
        .sheet(item: $vinylToEdit) { vinyl in
            EditCoverSheet(vinyl: vinyl)
        }
    }

    private func sortVinyls(_ lhs: Vinyl, _ rhs: Vinyl) -> Bool {
        let artistComparison = lhs.artist.localizedCaseInsensitiveCompare(rhs.artist)

        if artistComparison == .orderedSame {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return artistComparison == .orderedAscending
    }
}
