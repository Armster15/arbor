import SwiftUI

struct RecentSearchesView: View {
    let searches: [RecentSearchEntry]
    let onSelect: (RecentSearchEntry) -> Void
    let onClear: () -> Void

    var body: some View {
        if searches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent searches")
                        .font(.headline)
                        .foregroundColor(Color("PrimaryText"))
                    Spacer()
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No recent searches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Search for a song, artist, or paste a link")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 16)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    Section {
                        ForEach(searches) { entry in
                            RecentSearchRow(entry: entry) {
                                onSelect(entry)
                            }
                            
                            if entry.id != searches.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Recent searches")
                                .font(.headline)
                                .foregroundColor(Color("PrimaryText"))

                            Spacer()

                            Button("Clear") {
                                onClear()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }
}

struct RecentSearchRow: View {
    let entry: RecentSearchEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: entry.provider.symbolName)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.body)
                        .foregroundColor(Color("PrimaryText"))
                        .lineLimit(2)

                    Text(formatArtists(entry.artists))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .buttonStyle(.plain)
    }
}

