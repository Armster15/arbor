import SwiftUI
import ScrobbleKit
import SPIndicator

struct LastFMScreen: View {
    private let store = LastFMCredentialsStore()
    
    @State private var loggedInUsername: String = ""
    @State private var profileImageURL: URL? = nil
    @State private var scrobbleCount: Int? = nil
    @State private var isLoadingUserInfo: Bool = false
    @State private var userInfoErrorMessage: String? = nil
    @State private var showLogoutConfirmation: Bool = false
    
    private func loadFromKeychain() {
        loggedInUsername = store.username ?? ""
        
        if loggedInUsername.isEmpty {
            profileImageURL = nil
            scrobbleCount = nil
        }
    }
    
    @MainActor
    private func loadUserInfo(username: String, apiKey: String, apiSecret: String) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUsername.isEmpty,
              !trimmedApiKey.isEmpty,
              !trimmedApiSecret.isEmpty else { return }
        
        isLoadingUserInfo = true
        userInfoErrorMessage = nil
        defer { isLoadingUserInfo = false }
        
        do {
            let manager = SBKManager(apiKey: trimmedApiKey, secret: trimmedApiSecret)
            let user = try await manager.getInfo(forUser: "ghloug")
            scrobbleCount = user.playcount
            if let url = user.image?.largestSize {
                profileImageURL = url
            } else {
                profileImageURL = nil
            }
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            userInfoErrorMessage = error.localizedDescription
        }
    }
    
    private func logOut() {
        do {
            try store.clear()
            loggedInUsername = ""
            profileImageURL = nil
            scrobbleCount = nil
        } catch {
            showAlert(title: "Log out failed", message: error.localizedDescription)
        }
    }
        
    var body: some View {
        ScrollView {
            VStack {
                if !loggedInUsername.isEmpty {
                    LoggedInLastFMView(
                        username: loggedInUsername,
                        profileImageURL: profileImageURL,
                        scrobbleCount: scrobbleCount,
                        isLoadingUserInfo: isLoadingUserInfo,
                        errorMessage: userInfoErrorMessage,
                        onLogoutTapped: {
                            showLogoutConfirmation = true
                        }
                    )
                } else {
                    LoggedOutLastFMView(store: store) { username in
                        loggedInUsername = username
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, 4)
        }
        .navigationTitle("last.fm")
        .onAppear {
            loadFromKeychain()
        }
        // runs an async task whenever the id value changes
        .task(id: loggedInUsername) {
            guard !loggedInUsername.isEmpty,
                  let apiKey = store.apiKey,
                  let apiSecret = store.apiSecret else { return }
            await loadUserInfo(username: loggedInUsername, apiKey: apiKey, apiSecret: apiSecret)
        }
        .alert("Log Out?", isPresented: $showLogoutConfirmation) {
            Button("Log Out", role: .destructive) {
                logOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out of Last.fm?")
        }
    }
}

private struct LoggedInLastFMView: View {
    let username: String
    let profileImageURL: URL?
    let scrobbleCount: Int?
    let isLoadingUserInfo: Bool
    let errorMessage: String?
    let onLogoutTapped: () -> Void
    
    private func formattedScrobbleCount() -> String? {
        guard let scrobbleCount else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: scrobbleCount)) ?? "\(scrobbleCount)"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    if let profileImageURL {
                        AsyncImage(url: profileImageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(Color("PrimaryText"))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Image("LastFMDefaultAvatar")
                                    .resizable()
                                    .scaledToFill()
                            @unknown default:
                                Image("LastFMDefaultAvatar")
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                    } else {
                        Image("LastFMDefaultAvatar")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(username)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("PrimaryText"))
                    
                    Text(isLoadingUserInfo ? "Loading scrobbles..." : "\(formattedScrobbleCount() ?? "0") scrobbles")
                        .font(.subheadline)
                        .foregroundColor(Color("PrimaryText"))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            if let errorMessage {
                Text("Couldn’t load Last.fm profile: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(role: .destructive) {
                onLogoutTapped()
            } label: {
                Text("Log Out")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .fontWeight(.semibold)
            .tint(.red)
            .padding(.horizontal)
        }
    }
}

private struct LoggedOutLastFMView: View {
    let store: LastFMCredentialsStore
    let onLoggedIn: (String) -> Void
    
    // form input values
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    
    @MainActor
    private func submit() async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUsername.isEmpty,
              !trimmedPassword.isEmpty,
              !trimmedApiKey.isEmpty,
              !trimmedApiSecret.isEmpty else {
            showAlert(title: "Missing info", message: "Please fill in all four fields.")
            return
        }
        
        isSubmitting = true
        errorMessage = nil

        // `defer` guarantees isSubmitting gets set back to false when the function ends, 
        // whether the login succeeds or fails in the catch block
        defer { isSubmitting = false }
        
        do {
            let manager = SBKManager(apiKey: trimmedApiKey, secret: trimmedApiSecret)
            let session = try await manager.startSession(username: trimmedUsername, password: trimmedPassword)
            
            try store.save(
                username: session.name,
                apiKey: trimmedApiKey,
                apiSecret: trimmedApiSecret,
                sessionKey: session.key
            )

            SPIndicatorView(title: "Signed in to Last.fm", preset: .done).present()
            
            username = ""
            password = ""
            apiKey = ""
            apiSecret = ""
            
            onLoggedIn(session.name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            LabeledTextField(
                label: "Username",
                placeholder: "Username",
                text: $username,
                isSecure: false,
                textContentType: .username,
                keyboardType: .asciiCapable,
                autocapitalization: .never,
                disableAutocorrection: true
            )
            
            LabeledTextField(
                label: "Password",
                placeholder: "Password",
                text: $password,
                isSecure: true,
                textContentType: .password,
                keyboardType: .asciiCapable,
                autocapitalization: .never,
                disableAutocorrection: true
            )
            
            LabeledTextField(
                label: "API Key",
                placeholder: "API Key",
                text: $apiKey,
                isSecure: false,
                textContentType: nil,
                keyboardType: .asciiCapable,
                autocapitalization: .never,
                disableAutocorrection: true
            )
            
            LabeledTextField(
                label: "API Secret",
                placeholder: "API Secret",
                text: $apiSecret,
                isSecure: true,
                textContentType: nil,
                keyboardType: .asciiCapable,
                autocapitalization: .never,
                disableAutocorrection: true
            )
        }
        
        Spacer(minLength: 24)
        
        if let errorMessage {
            Text("Couldn’t log in to Last.fm: \(errorMessage)")
                .font(.footnote)
                .foregroundColor(.red)
                .padding(.horizontal)
        }
        
        PrimaryActionButton(
            title: "Submit",
            isLoading: isSubmitting,
            isDisabled: false,
            action: {
                Task { await submit() }
            }
        )
    }
}
