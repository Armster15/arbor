import SwiftUI
import SDWebImageSwiftUI

struct SongInfo: View {
    let title: String
    let artist: String?
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?

    var body: some View {
        VStack(spacing: 16) {
            if let thumbnailUrl = thumbnailURL, let isSquare = thumbnailIsSquare {
                if isSquare == true {
                    ZStack(alignment: .topTrailing) {
                        WebImage(url: URL(string: thumbnailUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 180, height: 180)
                                .clipped()
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                        } placeholder: {
                            ProgressView()
                                .frame(width: 180, height: 180)
                        }
                        .transition(.fade(duration: 0.5))
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        WebImage(url: URL(string: thumbnailUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                        } placeholder: {
                            ProgressView()
                                .frame(height: 180)
                        }
                        .transition(.fade(duration: 0.5))
                    }
                }
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let artist = artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
