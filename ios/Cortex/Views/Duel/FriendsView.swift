import SwiftUI

/// Single Friends page reached from the "…" menu: a small switch between
/// the friends list (add by code, requests, friends) and the player's own
/// QR code with the scanner — one entry instead of two.
struct FriendsView: View {
    enum Page: String, CaseIterable, Identifiable {
        case friends = "Mes amis"
        case qrCode = "Mon QR code"
        var id: String { rawValue }
    }

    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss
    @State private var page: Page
    @Namespace private var pageNamespace

    init(initialPage: Page = .friends) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pagePicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Rectangle().fill(Theme.line).frame(height: 1.5)
                Group {
                    switch page {
                    case .friends:
                        ScrollView {
                            FriendsSection()
                                .padding(16)
                                .padding(.bottom, 32)
                        }
                    case .qrCode:
                        FriendQRView(isEmbedded: true)
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.opacity)
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: page)
            .background(Theme.background)
            .navigationTitle("Amis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .task { await online.refreshFriends() }
        }
    }

    private var pagePicker: some View {
        HStack(spacing: 4) {
            ForEach(Page.allCases) { item in
                let isSelected = page == item
                Button {
                    guard page != item else { return }
                    Haptics.tap()
                    page = item
                } label: {
                    Label(item.rawValue, systemImage: item == .friends ? "person.2.fill" : "qrcode")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(isSelected ? .white : Theme.inkMuted)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Theme.primary)
                                    .matchedGeometryEffect(id: "friendsPage", in: pageNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 17).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.line, lineWidth: 2))
    }
}
