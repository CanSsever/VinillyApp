//
//  FinalDashboardViews.swift
//  VinillyApp
//
//  Pulled from the latest friend-repo UI and kept separate
//  so the merged Collection and Manual Search remain intact.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Final Main Tab View

struct MainTabView: View {
    @State private var viewModel = CollectionViewModel()

    var body: some View {
        TabView {
            CollectionTabView(viewModel: viewModel)
                .tabItem { Label("Collection", systemImage: "music.note.list") }

            StatsTabView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            HiFiTabView(viewModel: viewModel)
                .tabItem { Label("Hi-Fi", systemImage: "headphones") }
        }
        .tint(.green)
    }
}

// MARK: - Stats View (Advanced Audiophile Dashboard)

struct StatsTabView: View {
    @Query private var vinyls: [Vinyl]

    private var totalRecords: Int { vinyls.count }

    private var uniqueArtistsCount: Int {
        Set(vinyls.map { $0.artist }).count
    }

    private var estimatedPlaytimeHours: String {
        let totalMinutes = vinyls.count * 42
        let hours = totalMinutes / 60
        return "\(hours)h"
    }

    private var artistStats: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: vinyls, by: { $0.artist }).mapValues { $0.count }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var genreStats: [(genre: String, count: Int)] {
        let counts = Dictionary(grouping: vinyls, by: {
            $0.genre.isEmpty ? "Unknown" : $0.genre
        }).mapValues { $0.count }

        return counts.map { (genre: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var topGenre: String {
        genreStats.first?.genre ?? "N/A"
    }

    private var decadeStats: [(decade: String, count: Int)] {
        let validYears = vinyls.compactMap { Int($0.year) }
        let grouped = Dictionary(grouping: validYears) { year -> String in
            let decadeStart = (year / 10) * 10
            return "\(decadeStart)s"
        }

        return grouped.map { (decade: $0.key, count: $0.value.count) }
            .sorted { $0.decade < $1.decade }
    }

    private var collectionVelocity: [(month: String, count: Int)] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: vinyls) { vinyl -> String in
            let components = calendar.dateComponents([.year, .month], from: vinyl.addedAt)
            let month = components.month ?? 1
            return calendar.shortMonthSymbols[month - 1]
        }

        return grouped.map { (month: $0.key, count: $0.value.count) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if vinyls.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 22) {
                        kpiHighlightsGrid

                        if collectionVelocity.count > 1 {
                            growthTrendCard
                        }

                        topArtistsCard

                        if genreStats.count > 1 {
                            genreBreakdownCard
                        }

                        if !decadeStats.isEmpty {
                            decadesCard
                        }

                        topArtistsLeaderboard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Analytics")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.green.gradient)
            }

            Text("No Analytics Available")
                .font(.title2.bold())

            Text("Add vinyls to your shelf to reveal your listening personality, collection timeline, and artist insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer(minLength: 120)
        }
    }

    private var kpiHighlightsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            KPIMetricCard(
                icon: "opticaldisc.fill",
                title: "Total Shelf",
                value: "\(totalRecords) LPs",
                accentColor: .green
            )

            KPIMetricCard(
                icon: "person.2.fill",
                title: "Unique Artists",
                value: "\(uniqueArtistsCount)",
                accentColor: .blue
            )

            KPIMetricCard(
                icon: "guitars.fill",
                title: "Top Genre",
                value: topGenre,
                accentColor: .orange
            )

            KPIMetricCard(
                icon: "play.circle.fill",
                title: "Est. Playtime",
                value: estimatedPlaytimeHours,
                accentColor: .purple
            )
        }
    }

    private var growthTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    "Growth Velocity",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .font(.headline)

                Spacer()

                Text("Collection Pace")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            }

            Chart(collectionVelocity, id: \.month) { item in
                AreaMark(
                    x: .value("Month", item.month),
                    y: .value("Added", item.count)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.4),
                            Color.green.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Month", item.month),
                    y: .value("Added", item.count)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .foregroundStyle(Color.green)
            }
            .frame(height: 140)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Most Collected Artists", systemImage: "crown.fill")
                .font(.headline)

            let topFive = Array(artistStats.prefix(5))

            Chart(topFive, id: \.name) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Artist", item.name)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(6)
                .annotation(
                    position: .trailing,
                    alignment: .leading
                ) {
                    Text("\(item.count)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption.weight(.medium))
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(topFive.count * 44, 140)))
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var genreBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(
                "Sound Spectrum",
                systemImage: "waveform.badge.magnifyingglass"
            )
            .font(.headline)

            HStack(spacing: 20) {
                Chart(genreStats, id: \.genre) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.65),
                        angularInset: 2.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(
                        by: .value("Genre", item.genre)
                    )
                }
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(
                        Array(genreStats.prefix(4)),
                        id: \.genre
                    ) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green.opacity(0.75))
                                .frame(width: 8, height: 8)

                            Text(item.genre)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)

                            Spacer()

                            let pct =
                                (Double(item.count) /
                                 Double(max(totalRecords, 1))) * 100

                            Text("\(Int(pct))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var decadesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                "Eras & Release Decades",
                systemImage: "clock.arrow.circlepath"
            )
            .font(.headline)

            Chart(decadeStats, id: \.decade) { item in
                BarMark(
                    x: .value("Decade", item.decade),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(6)
            }
            .frame(height: 120)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption2.weight(.medium))
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var topArtistsLeaderboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Artist Ranking", systemImage: "list.number")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(
                    Array(artistStats.prefix(6).enumerated()),
                    id: \.element.name
                ) { index, stat in
                    HStack(spacing: 14) {
                        Text(
                            index == 0 ? "🥇" :
                            index == 1 ? "🥈" :
                            index == 2 ? "🥉" :
                            "\(index + 1)"
                        )
                        .font(.subheadline.bold())
                        .frame(width: 28, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            Text(
                                "\(stat.count) " +
                                "\(stat.count == 1 ? "record" : "records")"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                    }

                    if index < min(artistStats.count - 1, 5) {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - KPI Card Component

struct KPIMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(accentColor)

                Spacer()
            }

            Text(value)
                .font(
                    .system(
                        size: 20,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.03),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Hi-Fi Studio Deck View

struct HiFiTabView: View {
    @Bindable var viewModel: CollectionViewModel

    @State private var showAddProfile = false
    @State private var newProfileName = ""

    @State private var showAddSetup = false
    @State private var newSetupGenre = ""
    @State private var activeProfileID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    audiophileHeaderBanner

                    ForEach($viewModel.hifiProfiles) { $profile in
                        HiFiProfileDeckView(
                            profile: $profile,
                            onAddGenre: {
                                activeProfileID = profile.id
                                showAddSetup = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("Hi-Fi Rack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddProfile = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
            }
            .alert(
                "New Listening Room",
                isPresented: $showAddProfile
            ) {
                TextField(
                    "E.g. Living Room Tubes, Studio Desk",
                    text: $newProfileName
                )

                Button("Cancel", role: .cancel) {
                    newProfileName = ""
                }

                Button("Create") {
                    if !newProfileName.isEmpty {
                        viewModel.addHiFiProfile(
                            name: newProfileName
                        )
                        newProfileName = ""
                    }
                }
            }
            .alert(
                "Add Sound Profile",
                isPresented: $showAddSetup
            ) {
                TextField(
                    "Music Genre (e.g. Ambient, Funk)",
                    text: $newSetupGenre
                )

                Button("Cancel", role: .cancel) {
                    newSetupGenre = ""
                }

                Button("Save Preset") {
                    if let id = activeProfileID,
                       !newSetupGenre.isEmpty {
                        viewModel.addSetup(
                            to: id,
                            genre: newSetupGenre
                        )
                        newSetupGenre = ""
                    }
                }
            }
        }
    }

    private var audiophileHeaderBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ANALOG EQUALIZER & DSP")
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundColor(.green)

                Text("Sound Tuning Center")
                    .font(.title3.bold())

                Text(
                    "Calibrate acoustic tone curves, balance & gain per setup."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "tuningfork")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding(18)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }
}

// MARK: - Profile Deck Component

struct HiFiProfileDeckView: View {
    @Binding var profile: HiFiProfile
    var onAddGenre: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hifispeaker.2.fill")
                    .foregroundColor(.green)

                Text(profile.name)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(profile.setups.count) Presets")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Color(UIColor.tertiarySystemFill)
                    )
                    .clipShape(Capsule())
            }

            if profile.setups.isEmpty {
                Text("No acoustic presets for this room yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach($profile.setups) { $setup in
                        NavigationLink {
                            HiFiDetailView(setup: $setup)
                        } label: {
                            HStack(spacing: 14) {
                                EQCurveMiniPreview(
                                    bass: setup.bass,
                                    mid: setup.mid,
                                    treble: setup.treble
                                )
                                .frame(width: 50, height: 32)

                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    Text(setup.genre)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)

                                    HStack(spacing: 6) {
                                        Text("B: \(Int(setup.bass))dB")
                                        Text("•")
                                        Text("M: \(Int(setup.mid))dB")
                                        Text("•")
                                        Text("T: \(Int(setup.treble))dB")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                if setup.isLoudnessEnabled {
                                    Text("LOUD")
                                        .font(
                                            .system(
                                                size: 9,
                                                weight: .black
                                            )
                                        )
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Color.orange.opacity(0.12)
                                        )
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: 4
                                            )
                                        )
                                }

                                Image(
                                    systemName: "slider.horizontal.3"
                                )
                                .font(.caption)
                                .foregroundColor(.green)
                            }
                            .padding(14)
                            .background(
                                Color(
                                    UIColor
                                        .tertiarySystemGroupedBackground
                                )
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                        }
                    }
                }
            }

            Button(action: onAddGenre) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Tuning Preset")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
            }
        }
        .padding(18)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Interactive Hardware Detail View

struct HiFiDetailView: View {
    @Binding var setup: HiFiSetup

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                interactiveCurveCard
                eqSlidersCard
                dspControlsCard
                notesCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationTitle(setup.genre)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var interactiveCurveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    "Frequency Response (DSP)",
                    systemImage: "waveform.path"
                )
                .font(.headline)

                Spacer()

                Text("REAL-TIME")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
            }

            let curvePoints = calculateCurvePoints(
                bass: setup.bass,
                mid: setup.mid,
                treble: setup.treble
            )

            Chart(curvePoints, id: \.freq) { pt in
                AreaMark(
                    x: .value("Frequency", pt.freq),
                    y: .value("Gain", pt.gain)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.4),
                            Color.green.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Frequency", pt.freq),
                    y: .value("Gain", pt.gain)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .foregroundStyle(Color.green)
            }
            .chartYScale(domain: -12...12)
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: [100, 1000, 10000]) { val in
                    AxisValueLabel {
                        if let hz = val.as(Int.self) {
                            Text(
                                hz >= 1000
                                ? "\(hz / 1000)kHz"
                                : "\(hz)Hz"
                            )
                            .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [-10, 0, 10]) { val in
                    AxisValueLabel {
                        if let db = val.as(Int.self) {
                            Text(
                                "\(db > 0 ? "+" : "")\(db)dB"
                            )
                            .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var eqSlidersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(
                "Tone Control Equalizer",
                systemImage: "slider.vertical.3"
            )
            .font(.headline)

            HardwareSliderRow(
                title: "Treble (Highs)",
                subtitle: "10 kHz Shelf",
                value: $setup.treble,
                range: -10...10,
                unit: "dB"
            )

            Divider()

            HardwareSliderRow(
                title: "Midrange (Vocals)",
                subtitle: "1 kHz Peaking",
                value: $setup.mid,
                range: -10...10,
                unit: "dB"
            )

            Divider()

            HardwareSliderRow(
                title: "Bass (Low End)",
                subtitle: "100 Hz Shelf",
                value: $setup.bass,
                range: -10...10,
                unit: "dB"
            )
        }
        .padding(20)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var dspControlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(
                "Staging & Sub-Bass",
                systemImage: "speaker.wave.3.fill"
            )
            .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stereo Balance")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(balanceText(setup.balance))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $setup.balance,
                    in: -5...5,
                    step: 1
                )
                .tint(
                    setup.balance == 0
                    ? .gray
                    : .green
                )
            }

            Divider()

            HardwareSliderRow(
                title: "Subwoofer LFE Gain",
                subtitle: "20Hz - 80Hz",
                value: $setup.subwooferLevel,
                range: 0...10,
                unit: "/10"
            )

            Divider()

            Toggle(isOn: $setup.isLoudnessEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loudness Contour")
                        .font(.subheadline.weight(.semibold))

                    Text(
                        "Boosts lows & highs during quiet late-night sessions"
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .tint(.green)
        }
        .padding(20)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "Acoustics & Cartridge Notes",
                systemImage: "note.text"
            )
            .font(.headline)

            TextEditor(text: $setup.notes)
                .frame(minHeight: 110)
                .padding(8)
                .background(
                    Color(
                        UIColor
                            .tertiarySystemGroupedBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
        }
        .padding(20)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private func balanceText(_ val: Double) -> String {
        if val == 0 { return "Center" }
        if val < 0 { return "L \(Int(abs(val)))" }
        return "R \(Int(val))"
    }

    private func calculateCurvePoints(
        bass: Double,
        mid: Double,
        treble: Double
    ) -> [(freq: Int, gain: Double)] {
        [
            (20, bass * 0.95),
            (60, bass),
            (150, bass * 0.8),
            (400, mid * 0.4),
            (1000, mid),
            (2500, mid * 0.4),
            (6000, treble * 0.7),
            (12000, treble),
            (20000, treble * 0.9)
        ]
    }
}

// MARK: - Mini EQ Preview Graphic

struct EQCurveMiniPreview: View {
    let bass: Double
    let mid: Double
    let treble: Double

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let midY = h / 2

            Path { path in
                let bY =
                    midY -
                    CGFloat(bass / 10.0) *
                    (h * 0.38)

                let mY =
                    midY -
                    CGFloat(mid / 10.0) *
                    (h * 0.38)

                let tY =
                    midY -
                    CGFloat(treble / 10.0) *
                    (h * 0.38)

                path.move(
                    to: CGPoint(
                        x: 0,
                        y: bY
                    )
                )

                path.addQuadCurve(
                    to: CGPoint(
                        x: w * 0.5,
                        y: mY
                    ),
                    control: CGPoint(
                        x: w * 0.25,
                        y: (bY + mY) / 2
                    )
                )

                path.addQuadCurve(
                    to: CGPoint(
                        x: w,
                        y: tY
                    ),
                    control: CGPoint(
                        x: w * 0.75,
                        y: (mY + tY) / 2
                    )
                )
            }
            .stroke(
                Color.green,
                style: StrokeStyle(
                    lineWidth: 2.5,
                    lineCap: .round
                )
            )
            .background(Color.black.opacity(0.05))
            .clipShape(
                RoundedRectangle(cornerRadius: 6)
            )
        }
    }
}

// MARK: - Hardware Slider Component

struct HardwareSliderRow: View {
    let title: String
    let subtitle: String

    @Binding var value: Double

    var range: ClosedRange<Double>
    var unit: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(
                    "\(value > 0 && unit == "dB" ? "+" : "")" +
                    "\(Int(value))\(unit)"
                )
                .font(
                    .system(
                        .subheadline,
                        design: .monospaced
                    )
                    .bold()
                )
                .foregroundColor(
                    value != 0
                    ? .green
                    : .secondary
                )
            }

            Slider(
                value: $value,
                in: range,
                step: 1
            )
            .tint(
                value == 0 && unit == "dB"
                ? .gray
                : .green
            )
        }
        .padding(.vertical, 2)
    }
}
