import SwiftUI
import SDWebImageSwiftUI

struct SongInfo: View {
    let title: String
    let artist: String
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?

    var body: some View {
        VStack(spacing: 16) {
            SongImage(
                width: 180,
                height: 180,
                
                thumbnailURL: thumbnailURL,
                thumbnailIsSquare: thumbnailIsSquare,
                isLarge: true
            )
            
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
    
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?
    var isLarge: Bool = false

    var body: some View {
        if let thumbnailUrl = thumbnailURL, let isSquare = thumbnailIsSquare {
            if isSquare == true {
                ZStack(alignment: .topTrailing) {
                    WebImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                            .cornerRadius(isLarge ? 12 : 8)
                            .shadow(color: .black.opacity(isLarge ? 0.15 : 0), radius: 6, x: 0, y: 2)
                    } placeholder: {
                        ProgressView()
                            .frame(width: width, height: height)
                    }
                    .transition(.fade(duration: 0.5))
                }
            } else {
                ZStack(alignment: .topTrailing) {
                    WebImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: height)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(isLarge ? 0.15 : 0), radius: 6, x: 0, y: 2)
                    } placeholder: {
                        ProgressView()
                            .frame(height: height)
                    }
                    .transition(.fade(duration: 0.5))
                }
            }
        }
        
        else {
            ZStack {
                Color.gray.opacity(0.2)
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
