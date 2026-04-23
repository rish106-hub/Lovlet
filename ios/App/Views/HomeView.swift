import SwiftUI

struct HomeView: View {
    let pair: Pair
    @ObservedObject var pairingViewModel: PairingViewModel
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if homeViewModel.isLoading {
                        ProgressView()
                    } else if let moment = homeViewModel.latestMoment {
                        AsyncImage(url: URL(string: moment.imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text(moment.text)
                            .font(.headline)
                    } else if let cached = homeViewModel.cachedWidgetMoment {
                        AsyncImage(url: URL(string: cached.imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text(cached.text)
                            .font(.headline)
                        Text("Showing cached latest moment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No moment yet")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink("Share a moment") {
                    CaptureMomentView(pairID: pair.id)
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh") {
                    Task { await homeViewModel.refresh(pairID: pair.id) }
                }
                .buttonStyle(.bordered)

                Button("Unlink pair", role: .destructive) {
                    Task { await pairingViewModel.unlinkPair() }
                }

#if DEBUG
                Divider()
                Button("⚡ Write dummy widget data") {
                    WidgetCacheStore.save(.moment(WidgetMoment(
                        text: "Test moment from dev bypass",
                        imageURL: "https://picsum.photos/400/300",
                        createdAt: Date()
                    )))
                }
                .foregroundStyle(.orange)
#endif
            }
            .padding()
            .navigationTitle("Latest Moment")
            .task {
                homeViewModel.loadCached()
                await homeViewModel.refresh(pairID: pair.id)
            }
        }
    }
}
