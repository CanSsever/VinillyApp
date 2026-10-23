//
//  ManualSearchView.swift
//  VinillyApp
//
//  Final manual search screen for the enriched offline catalog.
//

import SwiftUI
import SwiftData

struct ManualSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var collection: [Vinyl]

    var viewModel: CollectionViewModel

    @State private var searchText = ""
    @State private var addedVinylTitle = ""
    @State private var showAddedAlert = false
    @State private var showAlreadyAddedAlert = false

    private var searchResults: [Vinyl] {
        viewModel.searchManually(query: searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptySearchState
                } else if searchResults.isEmpty {
                    noResultsState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Artist or title"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Added to Collection", isPresented: $showAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\"\(addedVinylTitle)\" was added to your collection.")
            }
            .alert("Already in Collection", isPresented: $showAlreadyAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\"\(addedVinylTitle)\" is already in your collection.")
            }
        }
    }

    private var resultsList: some View {
        List {
            Section {
                ForEach(searchResults) { result in
                    Button {
                        addToCollection(result)
                    } label: {
                        HStack(spacing: 14) {
                            VinylCoverView(vinyl: result, size: 62)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(result.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)

                                Text(result.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                HStack(spacing: 5) {
                                    if isKnown(result.year) {
                                        Text(result.year)
                                    }

                                    if isKnown(result.year) && isKnown(result.genre) {
                                        Text("•")
                                    }

                                    if isKnown(result.genre) {
                                        Text(result.genre)
                                            .lineLimit(1)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            if collection.contains(where: { $0.barcode == result.barcode }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("\(searchResults.count) Results")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptySearchState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 110, height: 110)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.green.gradient)
            }

            Text("Search the Offline Catalog")
                .font(.title3.bold())

            Text("Type the beginning of an artist or record title to search the local Vinilly database.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 42)

            Text("No internet connection is required for catalog search.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "opticaldisc")
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text("No Records Found")
                .font(.title3.bold())

            Text("Try the beginning of the artist name or album title.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private func addToCollection(_ vinyl: Vinyl) {
        addedVinylTitle = vinyl.title

        if collection.contains(where: { $0.barcode == vinyl.barcode }) {
            showAlreadyAddedAlert = true
            return
        }

        modelContext.insert(vinyl)

        do {
            try modelContext.save()
            showAddedAlert = true
        } catch {
            print("❌ Manual search save failed: \(error)")
        }
    }

    private func isKnown(_ value: String) -> Bool {
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
