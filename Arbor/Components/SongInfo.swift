import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

struct SongInfo: View {
    let title: String
    let artist: String
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?
    let thumbnailForceSquare: Bool

    init(
        title: String,
        artist: String,
        thumbnailURL: String?,
        thumbnailIsSquare: Bool?,
        thumbnailForceSquare: Bool = true
    ) {
        self.title = title
        self.artist = artist
        self.thumbnailURL = thumbnailURL
        self.thumbnailIsSquare = thumbnailIsSquare
        self.thumbnailForceSquare = thumbnailForceSquare
    }

    var body: some View {
        VStack(spacing: 16) {
            SongImage(
                width: 180,
                height: 180,
                isLarge: true,

                thumbnailURL: thumbnailURL,
                thumbnailIsSquare: thumbnailIsSquare,
                thumbnailForceSquare: thumbnailForceSquare,
            )
            .contextMenu {
                Group {
                    Button {
                        let url = self.thumbnailURL.flatMap { URL(string: $0) }
                        
                        guard let url = url else {
                            return
                        }
                        
                        SDWebImageManager.shared.loadImage(with: url, options: [.highPriority, .retryFailed, .scaleDownLargeImages], progress: nil) { image, _, error, _, finished, _ in
                            guard error == nil, finished, let image else {
                                print("Failed to load artwork via SDWebImage: \(error?.localizedDescription ?? "Unknown error")")
                                return
                            }
                            
                            // saves UIImage to user's photo library
                            // https://www.hackingwithswift.com/books/ios-swiftui/how-to-save-images-to-the-users-photo-library
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }

                    } label: {
                        Label("Save Cover to Photos", systemImage: "photo.badge.arrow.down")
                    }
                }
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text(artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct SongImage: View {
    let width: CGFloat
    let height: CGFloat
    var isLarge: Bool = false
    
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?
    var thumbnailForceSquare: Bool = true

    private var squareSide: CGFloat {
        min(width, height)
    }

    var body: some View {
        if let thumbnailUrl = thumbnailURL, let isSquare = thumbnailIsSquare {
            ZStack(alignment: .topTrailing) {
                WebImage(url: URL(string: thumbnailUrl)) { image in
                    let base = image
                        .resizable()
                        .scaledToFill()

                    if thumbnailForceSquare {
                        base
                            .frame(width: squareSide, height: squareSide)
                            .clipped()
                            .cornerRadius(isLarge ? 12 : 8)
                            .shadow(color: .black.opacity(isLarge ? 0.15 : 0), radius: 6, x: 0, y: 2)
                    } else if isSquare {
                        base
                            .frame(width: width, height: height)
                            .clipped()
                            .cornerRadius(isLarge ? 12 : 8)
                            .shadow(color: .black.opacity(isLarge ? 0.15 : 0), radius: 6, x: 0, y: 2)
                    } else {
                        base
                            .frame(height: height)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(isLarge ? 0.15 : 0), radius: 6, x: 0, y: 2)
                    }
                } placeholder: {
                    if thumbnailForceSquare {
                        ProgressView()
                            .frame(width: squareSide, height: squareSide)
                    } else if isSquare {
                        ProgressView()
                            .frame(width: width, height: height)
                    } else {
                        ProgressView()
                            .frame(height: height)
                    }
                }
                .transition(.fade(duration: 0.5))
            }
        }
        
        else {
            ZStack {
                Color.gray.opacity(0.2)
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .font(.system(size: min(width, height) * 0.5))
            }
            .frame(
                width: thumbnailForceSquare ? squareSide : width,
                height: thumbnailForceSquare ? squareSide : height
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
