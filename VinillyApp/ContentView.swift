import SwiftUI
import Observation
import Charts
import VisionKit
import SwiftData
import PhotosUI
import UIKit

// MARK: - App Entry Point & ContentView

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Cover

struct VinylCoverView: View {
    let vinyl: Vinyl
    let size: CGFloat

    var body: some View {
        Group {
            if let customData = vinyl.customImageData,
               let uiImage = UIImage(data: customData) {

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()

            } else if let coverUrl = vinyl.coverUrl,
                      let url = URL(string: coverUrl) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    default:
                        customPlaceholder
                    }
                }

            } else {
                customPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.28),
            radius: 10,
            x: 0,
            y: 7
        )
    }

    private var customPlaceholder: some View {

        let bgColor = Color(
            hex: vinyl.customColorHex ?? "#1E1E1E"
        )

        let emoji = vinyl.customEmoji ?? ""

        return ZStack {

            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(bgColor.gradient)

            Circle()
                .strokeBorder(
                    Color.white.opacity(0.08),
                    lineWidth: size * 0.12
                )
                .padding(size * 0.1)

            if !emoji.isEmpty {

                Text(emoji)
                    .font(
                        .system(
                            size: size * 0.35
                        )
                    )

            } else {

                Image(
                    systemName: "opticaldisc.fill"
                )
                .resizable()
                .scaledToFit()
                .frame(
                    width: size * 0.32
                )
                .foregroundColor(
                    .white.opacity(0.85)
                )
            }
        }
    }
}

// MARK: - Color Hex

extension Color {

    init(hex: String) {

        let cleanHex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )

        var int: UInt64 = 0

        Scanner(
            string: cleanHex
        )
        .scanHexInt64(&int)

        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleanHex.count {

        case 6:

            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:

            r = 30
            g = 30
            b = 30
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Collection Group Models

struct VinylCollectionGroup: Identifiable {

    let id: String
    let title: String
    let vinyls: [Vinyl]
}

struct CollectionGroupSelection: Identifiable {

    let id = UUID()

    let title: String
    let systemImage: String
    let vinyls: [Vinyl]
}

// MARK: - HiFi Models

struct HiFiProfile: Identifiable, Hashable {

    let id = UUID()

    var name: String
    var setups: [HiFiSetup]
}

struct HiFiSetup: Identifiable, Hashable {

    let id = UUID()

    var genre: String
    var notes: String

    var bass: Double
    var mid: Double
    var treble: Double

    var balance: Double
    var subwooferLevel: Double

    var isLoudnessEnabled: Bool
}

// MARK: - ViewModel

@Observable
class CollectionViewModel {

    var hifiProfiles: [HiFiProfile] = [

        HiFiProfile(
            name: "Living Room Setup (Towers)",
            setups: [

                HiFiSetup(
                    genre: "Rock",
                    notes: "Pronounced mid-bass, attenuated tweeters.",
                    bass: 2,
                    mid: 1,
                    treble: -1,
                    balance: 0,
                    subwooferLevel: 4,
                    isLoudnessEnabled: false
                ),

                HiFiSetup(
                    genre: "Jazz",
                    notes: "Direct/Flat to keep brass natural.",
                    bass: 0,
                    mid: 0,
                    treble: 0,
                    balance: 0,
                    subwooferLevel: 2,
                    isLoudnessEnabled: false
                )
            ]
        ),

        HiFiProfile(
            name: "Studio Setup (Bookshelf)",
            setups: [

                HiFiSetup(
                    genre: "Pop",
                    notes: "Loudness active for low-volume listening.",
                    bass: 3,
                    mid: 0,
                    treble: 2,
                    balance: -1,
                    subwooferLevel: 6,
                    isLoudnessEnabled: true
                )
            ]
        )
    ]

    func searchByBarcode(
        _ code: String
    ) -> Vinyl? {

        DatabaseService.shared.searchByBarcode(
            code
        )
    }

    func searchManually(
        query: String
    ) -> [Vinyl] {

        DatabaseService.shared.searchByText(
            query: query
        )
    }

    func getOtherVinylsByArtist(
        artist: String,
        excludingBarcode: String
    ) -> [Vinyl] {

        DatabaseService.shared
            .fetchOtherVinylsByArtist(
                artist: artist,
                excludingBarcode: excludingBarcode
            )
    }

    func addHiFiProfile(
        name: String
    ) {

        hifiProfiles.append(
            HiFiProfile(
                name: name,
                setups: []
            )
        )
    }

    func addSetup(
        to profileID: UUID,
        genre: String
    ) {

        guard let index = hifiProfiles.firstIndex(
            where: {
                $0.id == profileID
            }
        ) else {
            return
        }

        hifiProfiles[index].setups.append(
            HiFiSetup(
                genre: genre,
                notes: "",
                bass: 0,
                mid: 0,
                treble: 0,
                balance: 0,
                subwooferLevel: 0,
                isLoudnessEnabled: false
            )
        )
    }
}

// MARK: - Main Tab View

struct LegacyMainTabView: View {

    @State private var viewModel =
        CollectionViewModel()

    var body: some View {

        TabView {

            CollectionTabView(
                viewModel: viewModel
            )
            .tabItem {
                Label(
                    "Collection",
                    systemImage: "music.note.list"
                )
            }

            StatsTabView()
                .tabItem {
                    Label(
                        "Stats",
                        systemImage: "chart.bar.fill"
                    )
                }

            HiFiTabView(
                viewModel: viewModel
            )
            .tabItem {
                Label(
                    "Hi-Fi",
                    systemImage: "headphones"
                )
            }

            Text("Settings")
                .tabItem {
                    Label(
                        "Settings",
                        systemImage: "gearshape.fill"
                    )
                }
        }
        .tint(.green)
    }
}

// MARK: - Collection

struct LegacyCollectionTabView: View {
    
    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Vinyl.addedAt,
        order: .reverse
    )
    private var vinyls: [Vinyl]

    var viewModel: CollectionViewModel

    @AppStorage("hasSeenOnboarding")
    private var hasSeenOnboarding = false

    @State private var showOnboarding = false

    @State private var showAddMenu = false
    @State private var showScanner = false
    @State private var showManualSearch = false

    @State private var scannedCode: String?

    @State private var showFoundAlert = false
    @State private var showNotFoundAlert = false

    @State private var lastFoundVinyl: Vinyl?
    @State private var lastFailedBarcode = ""

    @State private var selectedVinylForDetail: Vinyl?
    @State private var selectedVinylToEdit: Vinyl?

    @State private var selectedGroup:
        CollectionGroupSelection?

    // MARK: Collection Data

    private var recentlyAdded: [Vinyl] {

        Array(
            vinyls.prefix(12)
        )
    }

    private var artistGroups:
        [VinylCollectionGroup] {

        let filtered = vinyls.filter {

            isValidMetadata(
                $0.artist,
                unknownValues: [
                    "unknown",
                    "unknown artist"
                ]
            )
        }

        let groups = Dictionary(
            grouping: filtered,
            by: {
                $0.artist
            }
        )

        return groups.map { key, values in

            VinylCollectionGroup(
                id: "artist-\(key.lowercased())",
                title: key,
                vinyls: values.sorted {
                    $0.title.localizedCaseInsensitiveCompare(
                        $1.title
                    ) == .orderedAscending
                }
            )

        }
        .sorted {

            $0.title.localizedCaseInsensitiveCompare(
                $1.title
            ) == .orderedAscending
        }
    }

    private var genreGroups:
        [VinylCollectionGroup] {

        let filtered = vinyls.filter {

            isValidMetadata(
                $0.genre,
                unknownValues: [
                    "unknown",
                    "n/d",
                    "n/a"
                ]
            )
        }

        let groups = Dictionary(
            grouping: filtered,
            by: {
                $0.genre
            }
        )

        return groups.map { key, values in

            VinylCollectionGroup(
                id: "genre-\(key.lowercased())",
                title: key,
                vinyls: values
            )

        }
        .sorted {

            $0.title.localizedCaseInsensitiveCompare(
                $1.title
            ) == .orderedAscending
        }
    }

    private var yearGroups:
        [VinylCollectionGroup] {

        let filtered = vinyls.filter {

            isValidMetadata(
                $0.year,
                unknownValues: [
                    "unknown",
                    "n/d",
                    "n/a",
                    "0"
                ]
            )
        }

        let groups = Dictionary(
            grouping: filtered,
            by: {
                $0.year
            }
        )

        return groups.map { key, values in

            VinylCollectionGroup(
                id: "year-\(key)",
                title: key,
                vinyls: values
            )

        }
        .sorted {

            let first =
                Int($0.title) ?? 0

            let second =
                Int($1.title) ?? 0

            return first > second
        }
    }

    private func isValidMetadata(
        _ value: String,
        unknownValues: [String]
    ) -> Bool {

        let normalized = value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        guard !normalized.isEmpty else {
            return false
        }

        return !unknownValues.contains(
            normalized
        )
    }

    // MARK: Body

    var body: some View {

        NavigationStack {

            Group {

                if vinyls.isEmpty {

                    emptyCollectionView

                } else {

                    collectionLibraryView
                }
            }
            .navigationTitle(
                "My Collection"
            )
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button {
                        showAddMenu = true
                    } label: {

                        Image(
                            systemName: "plus"
                        )
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    }
                }
            }
            .onAppear {

                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }

            // MARK: Sheets

            .sheet(
                isPresented: $showOnboarding
            ) {

                OnboardingView(
                    hasSeenOnboarding:
                        $hasSeenOnboarding
                )
            }

            .sheet(
                item: $selectedVinylToEdit
            ) { vinyl in

                EditCoverSheet(
                    vinyl: vinyl
                )
            }

            .sheet(
                item: $selectedVinylForDetail
            ) { vinyl in

                NavigationStack {

                    VinylDetailView(
                        vinyl: vinyl,
                        viewModel: viewModel
                    )
                }
            }

            .sheet(
                item: $selectedGroup
            ) { group in

                NavigationStack {

                    CollectionGroupDetailView(
                        group: group,
                        viewModel: viewModel
                    )
                }
            }

            .sheet(
                isPresented: $showAddMenu
            ) {

                addMenu
            }

            .sheet(
                isPresented: $showManualSearch
            ) {

                ManualSearchView(
                    viewModel: viewModel
                )
            }

            // MARK: Scanner

            .fullScreenCover(
                isPresented: $showScanner
            ) {

                ZStack {

                    if DataScannerViewController
                        .isSupported &&
                        DataScannerViewController
                        .isAvailable {

                        ScannerView(
                            scannedCode:
                                $scannedCode
                        )
                        .ignoresSafeArea()

                    } else {

                        Color.black
                            .ignoresSafeArea()

                        Text(
                            "Camera not supported or permission denied."
                        )
                        .foregroundColor(.white)
                    }

                    VStack {

                        HStack {

                            Spacer()

                            Button {

                                showScanner = false

                            } label: {

                                Image(
                                    systemName:
                                        "xmark.circle.fill"
                                )
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()
                            }
                        }

                        Spacer()
                    }
                }
            }

            // MARK: Barcode Result

            .onChange(
                of: scannedCode
            ) { _, code in

                guard let validCode = code
                else {
                    return
                }

                showScanner = false

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.35
                ) {

                    if let found =
                        viewModel.searchByBarcode(
                            validCode
                        ) {

                        modelContext.insert(
                            found
                        )

                        do {

                            try modelContext.save()

                        } catch {

                            print(
                                "❌ Error saving vinyl: \(error)"
                            )
                        }

                        lastFoundVinyl =
                            found

                        showFoundAlert =
                            true

                    } else {

                        lastFailedBarcode =
                            validCode

                        showNotFoundAlert =
                            true
                    }
                }

                scannedCode = nil
            }

            // MARK: Alerts

            .alert(
                "Vinyl Found! 🎉",
                isPresented:
                    $showFoundAlert,
                presenting:
                    lastFoundVinyl
            ) { _ in

                Button(
                    "Great!",
                    role: .cancel
                ) { }

            } message: { vinyl in

                Text(
                    """
                    Added to your collection:
                    "\(vinyl.title)" by \(vinyl.artist)
                    """
                )
            }

            .alert(
                "No Results Found",
                isPresented:
                    $showNotFoundAlert
            ) {

                Button(
                    "Search Manually"
                ) {

                    showManualSearch =
                        true
                }

                Button(
                    "Cancel",
                    role: .cancel
                ) { }

            } message: {

                Text(
                    """
                    No match found for barcode '\(lastFailedBarcode)' in the offline database.

                    Would you like to search by title or artist?
                    """
                )
            }
        }
    }

    // MARK: Empty Collection

    private var emptyCollectionView:
        some View {

        VStack(spacing: 20) {

            Spacer()

            Image(
                systemName:
                    "opticaldisc.fill"
            )
            .font(
                .system(
                    size: 90,
                    weight: .light
                )
            )
            .foregroundStyle(
                .green.gradient
            )
            .symbolEffect(
                .pulse.byLayer,
                options: .repeating
            )

            Text(
                "Your Collection is Empty"
            )
            .font(.title2)
            .fontWeight(.bold)

            Text(
                """
                Add your first vinyl by scanning the barcode on the back cover or searching the offline database.
                """
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Button {

                showAddMenu = true

            } label: {

                Label(
                    "Add Vinyl",
                    systemImage: "plus"
                )
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(
                    color: .green.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .padding(.top, 10)

            Spacer()
        }
    }

    // MARK: Collection Library

    private var collectionLibraryView:
        some View {

        ScrollView {

            LazyVStack(
                alignment: .leading,
                spacing: 34
            ) {

                // Summary

                HStack {

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(
                            "\(vinyls.count)"
                        )
                        .font(.largeTitle)
                        .fontWeight(.bold)

                        Text(
                            vinyls.count == 1
                            ? "record"
                            : "records"
                        )
                        .foregroundColor(
                            .secondary
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            "opticaldisc.fill"
                    )
                    .font(
                        .system(size: 42)
                    )
                    .foregroundStyle(
                        .green.gradient
                    )
                }
                .padding(.horizontal)

                // Recently Added

                if !recentlyAdded.isEmpty {

                    CollectionSectionHeader(
                        title: "Recently Added",
                        count:
                            recentlyAdded.count
                    )

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {

                        HStack(
                            spacing: 18
                        ) {

                            ForEach(
                                recentlyAdded
                            ) { vinyl in

                                interactiveVinylCard(
                                    vinyl,
                                    size: 155
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }
                }

                // Artists

                if !artistGroups.isEmpty {

                    CollectionSectionHeader(
                        title: "Artists",
                        count:
                            artistGroups.count
                    )

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {

                        HStack(
                            spacing: 18
                        ) {

                            ForEach(
                                artistGroups
                            ) { group in

                                Button {

                                    selectedGroup =
                                        CollectionGroupSelection(
                                            title:
                                                group.title,
                                            systemImage:
                                                "person.fill",
                                            vinyls:
                                                group.vinyls
                                        )

                                } label: {

                                    CollectionGroupCard(
                                        group: group,
                                        systemImage:
                                            "person.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Genres

                if !genreGroups.isEmpty {

                    CollectionSectionHeader(
                        title: "Genres",
                        count:
                            genreGroups.count
                    )

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {

                        HStack(
                            spacing: 14
                        ) {

                            ForEach(
                                genreGroups
                            ) { group in

                                Button {

                                    selectedGroup =
                                        CollectionGroupSelection(
                                            title:
                                                group.title,
                                            systemImage:
                                                "music.note",
                                            vinyls:
                                                group.vinyls
                                        )

                                } label: {

                                    MetadataGroupCard(
                                        title:
                                            group.title,
                                        count:
                                            group.vinyls.count,
                                        systemImage:
                                            "music.note"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Years

                if !yearGroups.isEmpty {

                    CollectionSectionHeader(
                        title: "Years",
                        count:
                            yearGroups.count
                    )

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {

                        HStack(
                            spacing: 14
                        ) {

                            ForEach(
                                yearGroups
                            ) { group in

                                Button {

                                    selectedGroup =
                                        CollectionGroupSelection(
                                            title:
                                                group.title,
                                            systemImage:
                                                "calendar",
                                            vinyls:
                                                group.vinyls
                                        )

                                } label: {

                                    MetadataGroupCard(
                                        title:
                                            group.title,
                                        count:
                                            group.vinyls.count,
                                        systemImage:
                                            "calendar"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // All Records

                CollectionSectionHeader(
                    title: "All Records",
                    count:
                        vinyls.count
                )

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 145,
                                maximum: 175
                            ),
                            spacing: 18
                        )
                    ],
                    spacing: 26
                ) {

                    ForEach(
                        vinyls
                    ) { vinyl in

                        interactiveVinylCard(
                            vinyl,
                            size: 145
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .padding(.top, 12)
        }
    }

    // MARK: Reusable Vinyl Card

    @ViewBuilder
    private func interactiveVinylCard(
        _ vinyl: Vinyl,
        size: CGFloat
    ) -> some View {

        VinylCollectionCard(
            vinyl: vinyl,
            size: size
        )
        .contentShape(Rectangle())
        .onTapGesture {

            selectedVinylForDetail =
                vinyl
        }
        .contextMenu {

            Button {

                selectedVinylToEdit =
                    vinyl

            } label: {

                Label(
                    "Customize Cover",
                    systemImage:
                        "paintbrush.fill"
                )
            }

            Button(
                role: .destructive
            ) {

                modelContext.delete(
                    vinyl
                )

                try? modelContext.save()

            } label: {

                Label(
                    "Remove from Collection",
                    systemImage: "trash"
                )
            }
        }
    }

    // MARK: Add Menu

    private var addMenu:
        some View {

        VStack(spacing: 16) {

            Text(
                "Add to your collection"
            )
            .font(.headline)
            .padding(.top, 10)

            Text(
                "Choose how to add your vinyl"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            Button {

                showAddMenu = false

                DispatchQueue.main
                    .asyncAfter(
                        deadline:
                            .now() + 0.2
                    ) {

                        showScanner = true
                    }

            } label: {

                Text("Scan Barcode")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding()
                    .background(
                        Color.blue
                    )
                    .cornerRadius(12)
            }

            Button {

                showAddMenu = false

                DispatchQueue.main
                    .asyncAfter(
                        deadline:
                            .now() + 0.2
                    ) {

                        showManualSearch =
                            true
                    }

            } label: {

                Text("Search Manually")
                    .font(.headline)
                    .foregroundColor(
                        .primary
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding()
                    .background(
                        Color.gray.opacity(
                            0.16
                        )
                    )
                    .cornerRadius(12)
            }

            Spacer()
        }
        .padding(24)
        .presentationDetents([
            .height(260)
        ])
        .presentationDragIndicator(
            .visible
        )
    }
}

// MARK: - Collection UI Components

struct CollectionSectionHeader: View {

    let title: String
    let count: Int

    var body: some View {

        HStack {

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(
                    .secondary
                )
        }
        .padding(.horizontal)
    }
}

struct VinylCollectionCard: View {

    let vinyl: Vinyl
    let size: CGFloat

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            VinylCoverView(
                vinyl: vinyl,
                size: size
            )

            Text(vinyl.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(vinyl.artist)
                .font(.caption)
                .foregroundColor(
                    .secondary
                )
                .lineLimit(1)
        }
        .frame(
            width: size,
            alignment: .leading
        )
    }
}

struct CollectionGroupCard: View {

    let group: VinylCollectionGroup
    let systemImage: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            ZStack(
                alignment: .bottomTrailing
            ) {

                if let first =
                    group.vinyls.first {

                    VinylCoverView(
                        vinyl: first,
                        size: 135
                    )
                }

                Text(
                    "\(group.vinyls.count)"
                )
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Color.black.opacity(
                        0.72
                    )
                )
                .clipShape(Capsule())
                .padding(7)
            }

            Text(group.title)
                .font(.headline)
                .lineLimit(1)

            Label(
                group.vinyls.count == 1
                ? "1 record"
                : "\(group.vinyls.count) records",
                systemImage:
                    systemImage
            )
            .font(.caption)
            .foregroundColor(
                .secondary
            )
            .lineLimit(1)
        }
        .frame(
            width: 135,
            alignment: .leading
        )
    }
}

struct MetadataGroupCard: View {

    let title: String
    let count: Int
    let systemImage: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Image(
                systemName:
                    systemImage
            )
            .font(.title2)
            .foregroundStyle(
                .green
            )

            Spacer()

            Text(title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(
                    .leading
                )

            Text(
                count == 1
                ? "1 record"
                : "\(count) records"
            )
            .font(.caption)
            .foregroundColor(
                .secondary
            )
        }
        .padding(16)
        .frame(
            width: 145,
            height: 125,
            alignment: .leading
        )
        .background(
            Color(
                UIColor
                    .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }
}

// MARK: - Group Detail

struct CollectionGroupDetailView: View {

    let group:
        CollectionGroupSelection

    let viewModel:
        CollectionViewModel

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {

        ScrollView {

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: 145,
                            maximum: 180
                        ),
                        spacing: 18
                    )
                ],
                spacing: 26
            ) {

                ForEach(
                    group.vinyls
                ) { vinyl in

                    NavigationLink {

                        VinylDetailView(
                            vinyl: vinyl,
                            viewModel:
                                viewModel
                        )

                    } label: {

                        VinylCollectionCard(
                            vinyl: vinyl,
                            size: 145
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(
            group.title
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {

            ToolbarItem(
                placement: .topBarLeading
            ) {

                Image(
                    systemName:
                        group.systemImage
                )
                .foregroundStyle(.green)
            }

            ToolbarItem(
                placement:
                    .topBarTrailing
            ) {

                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Edit Cover

struct EditCoverSheet: View {

    @Bindable var vinyl: Vinyl

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @State private var selectedItem:
        PhotosPickerItem?

    let colorPalette = [
        "#1C1C1E",
        "#2C3E50",
        "#E63946",
        "#F4A261",
        "#E76F51",
        "#2A9D8F",
        "#457B9D",
        "#1D3557",
        "#6A4C93",
        "#8338EC",
        "#3A86FF",
        "#2B9348"
    ]

    let emojiSuggestions = [
        "🎵",
        "🎸",
        "🎷",
        "🎹",
        "✨",
        "🔥",
        "⚡️",
        "☕️",
        "🌙",
        "🌊",
        "🍄",
        "💿"
    ]

    var body: some View {

        NavigationStack {

            Form {

                Section {

                    HStack {

                        Spacer()

                        VinylCoverView(
                            vinyl: vinyl,
                            size: 150
                        )

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section(
                    header:
                        Text(
                            "Photo Library"
                        )
                ) {

                    PhotosPicker(
                        selection:
                            $selectedItem,
                        matching:
                            .images
                    ) {

                        Label(
                            "Choose from Library",
                            systemImage:
                                "photo.badge.plus"
                        )
                        .font(.headline)
                        .foregroundColor(
                            .green
                        )
                    }
                    .onChange(
                        of: selectedItem
                    ) { _, item in

                        Task {

                            if let data =
                                try? await item?
                                    .loadTransferable(
                                        type:
                                            Data.self
                                    ),
                               let uiImage =
                                UIImage(
                                    data: data
                                ),
                               let compressedData =
                                uiImage.jpegData(
                                    compressionQuality:
                                        0.75
                                ) {

                                vinyl
                                    .customImageData =
                                    compressedData

                                vinyl
                                    .customEmoji =
                                    nil

                                try?
                                    modelContext
                                        .save()
                            }
                        }
                    }

                    if vinyl.customImageData
                        != nil {

                        Button(
                            role: .destructive
                        ) {

                            vinyl.customImageData =
                                nil

                            try?
                                modelContext
                                    .save()

                        } label: {

                            Label(
                                "Remove Custom Photo",
                                systemImage:
                                    "trash"
                            )
                        }
                    }
                }

                Section(
                    header:
                        Text(
                            "Placeholder Color"
                        )
                ) {

                    LazyVGrid(
                        columns: Array(
                            repeating:
                                GridItem(
                                    .flexible(),
                                    spacing: 12
                                ),
                            count: 6
                        ),
                        spacing: 12
                    ) {

                        ForEach(
                            colorPalette,
                            id: \.self
                        ) { hex in

                            Circle()
                                .fill(
                                    Color(
                                        hex: hex
                                    )
                                )
                                .frame(
                                    height: 38
                                )
                                .overlay {

                                    Circle()
                                        .stroke(
                                            Color
                                                .primary,
                                            lineWidth:
                                                vinyl
                                                .customColorHex
                                                == hex
                                                ? 3
                                                : 0
                                        )
                                }
                                .onTapGesture {

                                    vinyl
                                        .customColorHex =
                                        hex

                                    vinyl
                                        .customImageData =
                                        nil

                                    try?
                                        modelContext
                                            .save()
                                }
                        }
                    }
                    .padding(
                        .vertical,
                        6
                    )
                }

                Section(
                    header:
                        Text(
                            "Placeholder Emoji"
                        )
                ) {

                    LazyVGrid(
                        columns: Array(
                            repeating:
                                GridItem(
                                    .flexible(),
                                    spacing: 10
                                ),
                            count: 6
                        ),
                        spacing: 10
                    ) {

                        ForEach(
                            emojiSuggestions,
                            id: \.self
                        ) { emoji in

                            Text(emoji)
                                .font(
                                    .system(
                                        size: 28
                                    )
                                )
                                .frame(
                                    width: 44,
                                    height: 44
                                )
                                .background(
                                    vinyl
                                        .customEmoji
                                        == emoji
                                    ? Color
                                        .green
                                        .opacity(
                                            0.2
                                        )
                                    : Color
                                        .gray
                                        .opacity(
                                            0.12
                                        )
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius:
                                            8
                                    )
                                )
                                .overlay {

                                    RoundedRectangle(
                                        cornerRadius:
                                            8
                                    )
                                    .stroke(
                                        Color.green,
                                        lineWidth:
                                            vinyl
                                            .customEmoji
                                            == emoji
                                            ? 2
                                            : 0
                                    )
                                }
                                .onTapGesture {

                                    vinyl
                                        .customEmoji =
                                        emoji

                                    vinyl
                                        .customImageData =
                                        nil

                                    try?
                                        modelContext
                                            .save()
                                }
                        }
                    }
                    .padding(
                        .vertical,
                        6
                    )
                }
            }
            .navigationTitle(
                "Customize Cover"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(
                        .semibold
                    )
                }
            }
        }
    }
}

// MARK: - Vinyl Detail

struct VinylDetailView: View {

    @Bindable var vinyl: Vinyl

    var viewModel:
        CollectionViewModel

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @State private var otherVinyls:
        [Vinyl] = []

    @State private var showEditCover =
        false

    @State private var showAddedSuccessAlert =
        false

    @State private var newlyAddedVinylTitle =
        ""

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                ZStack(
                    alignment:
                        .bottomTrailing
                ) {

                    VinylCoverView(
                        vinyl: vinyl,
                        size: 260
                    )

                    Button {

                        showEditCover =
                            true

                    } label: {

                        Image(
                            systemName:
                                "paintbrush.fill"
                        )
                        .font(
                            .system(
                                size: 16,
                                weight: .bold
                            )
                        )
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            Color.black
                                .opacity(
                                    0.65
                                )
                        )
                        .clipShape(Circle())
                        .overlay {

                            Circle()
                                .stroke(
                                    Color.white
                                        .opacity(
                                            0.3
                                        ),
                                    lineWidth: 1
                                )
                        }
                    }
                    .padding(12)
                }
                .padding(.top, 16)

                VStack(spacing: 6) {

                    Text(vinyl.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(
                            .center
                        )

                    Text(vinyl.artist)
                        .font(.title3)
                        .foregroundColor(
                            .secondary
                        )
                }
                .padding(
                    .horizontal,
                    24
                )

                VStack(spacing: 14) {

                    InfoDetailRow(
                        icon: "calendar",
                        title:
                            "Release Year",
                        value:
                            vinyl.year
                    )

                    Divider()

                    InfoDetailRow(
                        icon:
                            "guitars.fill",
                        title: "Genre",
                        value:
                            vinyl.genre
                    )

                    Divider()

                    InfoDetailRow(
                        icon: "barcode",
                        title: "Barcode",
                        value:
                            vinyl.barcode
                    )

                    Divider()

                    InfoDetailRow(
                        icon:
                            "clock.badge.checkmark",
                        title: "Added on",
                        value:
                            vinyl.addedAt
                                .formatted(
                                    date:
                                        .abbreviated,
                                    time:
                                        .shortened
                                )
                    )
                }
                .padding(18)
                .background(
                    Color(
                        UIColor
                            .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style:
                            .continuous
                    )
                )
                .padding(
                    .horizontal,
                    20
                )

                // More by Artist

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    HStack {

                        Text(
                            "More by \(vinyl.artist)"
                        )
                        .font(.title3)
                        .fontWeight(.bold)

                        Spacer()
                    }
                    .padding(
                        .horizontal,
                        20
                    )

                    if otherVinyls.isEmpty {

                        HStack {

                            Spacer()

                            Text(
                                """
                                No other records found by this artist in the database.
                                """
                            )
                            .font(.subheadline)
                            .foregroundColor(
                                .secondary
                            )
                            .multilineTextAlignment(
                                .center
                            )
                            .padding(
                                .vertical,
                                16
                            )

                            Spacer()
                        }
                        .padding(
                            .horizontal,
                            20
                        )

                    } else {

                        ScrollView(
                            .horizontal,
                            showsIndicators: false
                        ) {

                            HStack(
                                spacing: 16
                            ) {

                                ForEach(
                                    otherVinyls
                                ) { other in

                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing: 8
                                    ) {

                                        VinylCoverView(
                                            vinyl:
                                                other,
                                            size: 140
                                        )

                                        Text(
                                            other.title
                                        )
                                        .font(
                                            .caption
                                        )
                                        .fontWeight(
                                            .semibold
                                        )
                                        .lineLimit(1)
                                        .frame(
                                            width:
                                                140,
                                            alignment:
                                                .leading
                                        )

                                        Text(
                                            other.year
                                        )
                                        .font(
                                            .caption2
                                        )
                                        .foregroundColor(
                                            .secondary
                                        )

                                        Button {

                                            modelContext
                                                .insert(
                                                    other
                                                )

                                            try?
                                                modelContext
                                                    .save()

                                            newlyAddedVinylTitle =
                                                other
                                                .title

                                            showAddedSuccessAlert =
                                                true

                                        } label: {

                                            Label(
                                                "Add",
                                                systemImage:
                                                    "plus"
                                            )
                                            .font(
                                                .caption
                                                    .bold()
                                            )
                                            .frame(
                                                maxWidth:
                                                    .infinity
                                            )
                                            .padding(
                                                .vertical,
                                                6
                                            )
                                            .background(
                                                Color
                                                    .green
                                                    .opacity(
                                                        0.15
                                                    )
                                            )
                                            .foregroundColor(
                                                .green
                                            )
                                            .clipShape(
                                                Capsule()
                                            )
                                        }
                                    }
                                    .frame(
                                        width: 140
                                    )
                                }
                            }
                            .padding(
                                .horizontal,
                                20
                            )
                        }
                    }
                }
                .padding(.top, 10)

                Spacer(
                    minLength: 30
                )
            }
        }
        .navigationTitle(
            "Record Details"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {

            ToolbarItem(
                placement:
                    .topBarTrailing
            ) {

                Button("Done") {
                    dismiss()
                }
                .fontWeight(
                    .semibold
                )
            }
        }
        .onAppear {

            otherVinyls =
                viewModel
                .getOtherVinylsByArtist(
                    artist:
                        vinyl.artist,
                    excludingBarcode:
                        vinyl.barcode
                )
        }
        .sheet(
            isPresented:
                $showEditCover
        ) {

            EditCoverSheet(
                vinyl: vinyl
            )
        }
        .alert(
            "Added to Collection! 🎉",
            isPresented:
                $showAddedSuccessAlert
        ) {

            Button(
                "OK",
                role: .cancel
            ) { }

        } message: {

            Text(
                """
                "\(newlyAddedVinylTitle)" has been added to your collection.
                """
            )
        }
    }
}

struct InfoDetailRow: View {

    let icon: String
    let title: String
    let value: String

    var body: some View {

        HStack {

            Label(
                title,
                systemImage: icon
            )
            .foregroundColor(
                .secondary
            )

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(
                    .trailing
                )
        }
        .font(.subheadline)
    }
}

// MARK: - Manual Search

struct LegacyManualSearchView: View {
    
    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    var viewModel:
        CollectionViewModel

    @State private var searchText =
        ""

    private var searchResults:
        [Vinyl] {

        viewModel.searchManually(
            query: searchText
        )
    }

    var body: some View {

        NavigationStack {

            List {

                if searchText.isEmpty {

                    Text(
                        "Search for a vinyl by artist or title in the database."
                    )
                    .foregroundColor(
                        .secondary
                    )
                    .listRowBackground(
                        Color.clear
                    )

                } else if searchResults.isEmpty {

                    ContentUnavailableView(
                        "No Results",
                        systemImage:
                            "magnifyingglass",
                        description:
                            Text(
                                "Try another artist or title."
                            )
                    )

                } else {

                    ForEach(
                        searchResults
                    ) { result in

                        Button {

                            modelContext.insert(
                                result
                            )

                            try?
                                modelContext
                                    .save()

                            dismiss()

                        } label: {

                            HStack(
                                spacing: 12
                            ) {

                                VinylCoverView(
                                    vinyl:
                                        result,
                                    size: 52
                                )

                                VStack(
                                    alignment:
                                        .leading,
                                    spacing: 3
                                ) {

                                    Text(
                                        result
                                            .title
                                    )
                                    .font(
                                        .headline
                                    )
                                    .foregroundColor(
                                        .primary
                                    )
                                    .lineLimit(2)

                                    Text(
                                        result
                                            .artist
                                    )
                                    .font(
                                        .subheadline
                                    )
                                    .foregroundColor(
                                        .secondary
                                    )
                                    .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt:
                    "Title or Artist"
            )
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Scanner

struct ScannerView:
    UIViewControllerRepresentable {

    @Binding var scannedCode:
        String?

    @Environment(\.dismiss)
    var dismiss

    func makeUIViewController(
        context: Context
    ) -> DataScannerViewController {

        let scanner =
            DataScannerViewController(
                recognizedDataTypes: [
                    .barcode()
                ],
                qualityLevel:
                    .balanced,
                recognizesMultipleItems:
                    false,
                isHighFrameRateTrackingEnabled:
                    false,
                isHighlightingEnabled:
                    true
            )

        scanner.delegate =
            context.coordinator

        try? scanner.startScanning()

        return scanner
    }

    func updateUIViewController(
        _ uiViewController:
            DataScannerViewController,
        context: Context
    ) { }

    func makeCoordinator()
        -> Coordinator {

        Coordinator(self)
    }

    class Coordinator:
        NSObject,
        DataScannerViewControllerDelegate {

        var parent:
            ScannerView

        init(
            _ parent:
                ScannerView
        ) {

            self.parent =
                parent
        }

        func dataScanner(
            _ dataScanner:
                DataScannerViewController,
            didAdd addedItems:
                [RecognizedItem],
            allItems:
                [RecognizedItem]
        ) {

            guard
                let item =
                    addedItems.first,
                case .barcode(
                    let barcode
                ) = item
            else {
                return
            }

            dataScanner.stopScanning()

            DispatchQueue.main.async {

                self.parent
                    .scannedCode =
                    barcode
                    .payloadStringValue

                self.parent.dismiss()
            }
        }
    }
}

// MARK: - Stats

struct LegacyStatsTabView: View {

    @Query
    private var vinyls:
        [Vinyl]

    private var artistStats:
        [(name: String, count: Int)] {

        let counts = Dictionary(
            grouping: vinyls,
            by: {
                $0.artist
            }
        )
        .mapValues {
            $0.count
        }

        return counts
            .map {
                (
                    name: $0.key,
                    count: $0.value
                )
            }
            .sorted {
                $0.count > $1.count
            }
    }

    var body: some View {

        NavigationStack {

            List {

                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Text(
                            "Most Collected"
                        )
                        .font(
                            .subheadline
                        )
                        .fontWeight(
                            .semibold
                        )
                        .foregroundColor(
                            .secondary
                        )

                        if artistStats.isEmpty {

                            Text(
                                "Add some vinyls to view statistics."
                            )
                            .font(.caption)
                            .foregroundColor(
                                .secondary
                            )
                            .padding(
                                .vertical,
                                20
                            )

                        } else {

                            Chart(
                                Array(
                                    artistStats
                                        .prefix(8)
                                ),
                                id: \.name
                            ) { stat in

                                BarMark(
                                    x: .value(
                                        "Artist",
                                        stat.name
                                    ),
                                    y: .value(
                                        "Count",
                                        stat.count
                                    )
                                )
                                .foregroundStyle(
                                    Color.green
                                        .gradient
                                )
                                .cornerRadius(4)
                            }
                            .frame(height: 220)
                        }
                    }
                    .padding(
                        .vertical,
                        8
                    )

                } header: {

                    Text("Overview")
                }

                if !artistStats.isEmpty {

                    Section(
                        header:
                            Text(
                                "Top Artists"
                            )
                    ) {

                        ForEach(
                            artistStats,
                            id: \.name
                        ) { stat in

                            HStack {

                                Text(
                                    stat.name
                                )

                                Spacer()

                                Text(
                                    "\(stat.count)"
                                )
                                .foregroundColor(
                                    .secondary
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(
                "Stats"
            )
        }
    }
}

// MARK: - Hi-Fi

struct LegacyHiFiTabView: View {

    @Bindable var viewModel:
        CollectionViewModel

    @State private var showAddProfile =
        false

    @State private var newProfileName =
        ""

    @State private var showAddSetup =
        false

    @State private var newSetupGenre =
        ""

    @State private var activeProfileID:
        UUID?

    var body: some View {

        NavigationStack {

            List {

                ForEach(
                    $viewModel
                        .hifiProfiles
                ) { $profile in

                    Section {

                        ForEach(
                            $profile
                                .setups
                        ) { $setup in

                            NavigationLink {

                                HiFiDetailView(
                                    setup: $setup
                                )

                            } label: {

                                Text(
                                    setup.genre
                                )
                                .font(
                                    .headline
                                )
                                .padding(
                                    .vertical,
                                    4
                                )
                            }
                        }

                        Button {

                            activeProfileID =
                                profile.id

                            showAddSetup =
                                true

                        } label: {

                            Label(
                                "Add Genre",
                                systemImage:
                                    "plus.circle.fill"
                            )
                            .foregroundColor(
                                .green
                            )
                            .font(
                                .subheadline
                            )
                        }

                    } header: {

                        Text(
                            profile.name
                        )
                        .font(.headline)
                        .foregroundColor(
                            .primary
                        )
                        .textCase(nil)
                    }
                }
            }
            .navigationTitle(
                "Hi-Fi Setups"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button {

                        showAddProfile =
                            true

                    } label: {

                        Image(
                            systemName:
                                "plus"
                        )
                        .foregroundColor(
                            .green
                        )
                    }
                }
            }
            .alert(
                "New Setup",
                isPresented:
                    $showAddProfile
            ) {

                TextField(
                    "Setup Name (e.g., Living Room)",
                    text:
                        $newProfileName
                )

                Button(
                    "Cancel",
                    role: .cancel
                ) {

                    newProfileName = ""
                }

                Button("Add") {

                    guard
                        !newProfileName
                            .isEmpty
                    else {
                        return
                    }

                    viewModel
                        .addHiFiProfile(
                            name:
                                newProfileName
                        )

                    newProfileName = ""
                }
            }
            .alert(
                "Add Preset",
                isPresented:
                    $showAddSetup
            ) {

                TextField(
                    "Genre (e.g., Electronic)",
                    text:
                        $newSetupGenre
                )

                Button(
                    "Cancel",
                    role: .cancel
                ) {

                    newSetupGenre = ""
                }

                Button("Add") {

                    guard
                        let id =
                            activeProfileID,
                        !newSetupGenre
                            .isEmpty
                    else {
                        return
                    }

                    viewModel.addSetup(
                        to: id,
                        genre:
                            newSetupGenre
                    )

                    newSetupGenre = ""
                }
            }
        }
    }
}

struct LegacyHiFiDetailView: View {

    @Binding var setup:
        HiFiSetup

    var body: some View {

        Form {

            Section(
                header:
                    Text(
                        "Equalizer (EQ)"
                    )
            ) {

                SliderRow(
                    title: "Treble",
                    value:
                        $setup.treble,
                    range: -10...10,
                    unit: "dB"
                )

                SliderRow(
                    title: "Midrange",
                    value:
                        $setup.mid,
                    range: -10...10,
                    unit: "dB"
                )

                SliderRow(
                    title: "Bass",
                    value:
                        $setup.bass,
                    range: -10...10,
                    unit: "dB"
                )
            }

            Section(
                header:
                    Text(
                        "System Controls"
                    )
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    HStack {

                        Text(
                            "L/R Balance"
                        )

                        Spacer()

                        Text(
                            balanceText(
                                setup.balance
                            )
                        )
                        .foregroundColor(
                            .secondary
                        )
                    }

                    Slider(
                        value:
                            $setup.balance,
                        in: -5...5,
                        step: 1
                    )
                    .tint(
                        setup.balance == 0
                        ? .gray
                        : .green
                    )
                }
                .padding(
                    .vertical,
                    4
                )

                SliderRow(
                    title:
                        "Subwoofer Level",
                    value:
                        $setup
                        .subwooferLevel,
                    range: 0...10,
                    unit: ""
                )

                Toggle(
                    "Loudness",
                    isOn:
                        $setup
                        .isLoudnessEnabled
                )
                .tint(.green)
            }

            Section(
                header:
                    Text(
                        "Listening & Placement Notes"
                    )
            ) {

                TextEditor(
                    text:
                        $setup.notes
                )
                .frame(
                    minHeight: 120
                )
            }
        }
        .navigationTitle(
            setup.genre
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private func balanceText(
        _ value: Double
    ) -> String {

        if value == 0 {
            return "Center"
        }

        if value < 0 {

            return "L \(Int(abs(value)))"
        }

        return "R \(Int(value))"
    }
}

struct SliderRow: View {

    let title: String

    @Binding var value:
        Double

    let range:
        ClosedRange<Double>

    let unit: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Text(title)

                Spacer()

                Text(
                    """
                    \(value > 0 && unit == "dB" ? "+" : "")\(Int(value)) \(unit)
                    """
                )
                .foregroundColor(
                    .secondary
                )
            }

            Slider(
                value: $value,
                in: range,
                step: 1
            )
            .tint(
                value == 0 &&
                unit == "dB"
                ? .gray
                : .green
            )
        }
        .padding(
            .vertical,
            4
        )
    }
}

// MARK: - Onboarding

struct OnboardingView: View {

    @Binding var hasSeenOnboarding:
        Bool

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {

        VStack(spacing: 28) {

            Spacer()

            VStack(spacing: 8) {

                Text(
                    "Welcome to"
                )
                .font(.title2)
                .foregroundColor(
                    .secondary
                )

                Text("Vinilly")
                    .font(
                        .system(
                            size: 44,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color.green.gradient
                    )
            }
            .padding(.top, 20)

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                FeatureRow(
                    icon:
                        "barcode.viewfinder",
                    color: .blue,
                    title:
                        "Instant Scanning",
                    description:
                        "Frame the barcode on the back cover to identify your record in seconds."
                )

                FeatureRow(
                    icon:
                        "externaldrive.fill.badge.checkmark",
                    color: .green,
                    title:
                        "100% Offline",
                    description:
                        "A complete archive built right into your device. No external APIs needed, browse anywhere."
                )

                FeatureRow(
                    icon:
                        "slider.vertical.3",
                    color: .orange,
                    title:
                        "Hi-Fi Profiles & Presets",
                    description:
                        "Save EQ settings tailored to each genre and sound system."
                )
            }
            .padding(
                .horizontal,
                24
            )

            Spacer()

            Button {

                hasSeenOnboarding =
                    true

                dismiss()

            } label: {

                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(
                        .white
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding()
                    .background(
                        Color.green
                    )
                    .cornerRadius(14)
            }
            .padding(
                .horizontal,
                24
            )
            .padding(
                .bottom,
                16
            )
        }
        .interactiveDismissDisabled()
    }
}

struct FeatureRow: View {

    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 16
        ) {

            Image(
                systemName: icon
            )
            .font(.title)
            .foregroundColor(
                color
            )
            .frame(
                width: 44,
                height: 44
            )
            .background(
                color.opacity(
                    0.15
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10
                )
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .font(
                        .headline
                    )

                Text(
                    description
                )
                .font(
                    .subheadline
                )
                .foregroundColor(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
