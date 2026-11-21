import SwiftData
import SwiftUI
import SchwipsCore

/// Which photo the viewer window shows.
struct PhotoTarget: Codable, Hashable {
    static let windowID = "photo"
    var wineNumber: Int
    var index: Int
}

/// "Diel Eierfels 2023 — IMG_5107", "2 of 3": the photo fitted to the
/// window, previous and next, the strip; ← → step, Esc or Space close, a
/// pinch zooms.
struct PhotoViewer: View {
    @Binding var target: PhotoTarget?
    @Query private var wines: [Wine]
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        let wine = wines.first { $0.number == target?.wineNumber }
        let photos = wine?.orderedPhotos ?? []
        let index = min(max(target?.index ?? 0, 0), max(photos.count - 1, 0))
        VStack(spacing: 0) {
            if let wine, !photos.isEmpty {
                HStack(spacing: 16) {
                    stepButton("chevron.left", label: Text("Previous photo"), enabled: index > 0) { step(-1, count: photos.count) }
                    StoredImage(data: photos[index].imageData)
                        .scaledToFit()
                        .scaleEffect(zoom * pinch)
                        .gesture(MagnifyGesture()
                            .updating($pinch) { value, state, _ in state = value.magnification }
                            .onEnded { zoom = min(max(zoom * $0.magnification, 1), 6) })
                        .onTapGesture(count: 2) { zoom = 1 }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    stepButton("chevron.right", label: Text("Next photo"), enabled: index < photos.count - 1) { step(1, count: photos.count) }
                }
                .padding(16)
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                        Button {
                            target?.index = offset
                            zoom = 1
                        } label: {
                            StoredImage(data: photo.thumbnailData)
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(offset == index ? Color.white : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.35))
                .navigationTitle(Text(verbatim: "\(WineText.fullName(wine)) — \(photos[index].fileName)"))
                #if os(macOS)
                .navigationSubtitle(Text("\(index + 1) of \(photos.count)"))
                #endif
            } else {
                ContentUnavailableView("No photos", systemImage: "photo")
            }
        }
        .background(Color(light: 0x1E1B19, dark: 0x1E1B19))
        .frame(minWidth: 480, minHeight: 480)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { step(-1, count: photos.count); return .handled }
        .onKeyPress(.rightArrow) { step(1, count: photos.count); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.space) { dismiss(); return .handled }
    }

    private func step(_ delta: Int, count: Int) {
        guard let current = target?.index else { return }
        let next = current + delta
        guard (0..<count).contains(next) else { return }
        target?.index = next
        zoom = 1
    }

    private func stepButton(_ symbol: String, label: Text, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.12)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}
