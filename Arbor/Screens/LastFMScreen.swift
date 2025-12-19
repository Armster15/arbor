import SwiftUI
import ScrobbleKit

struct LastFMScreen: View {
    private let store = LastFMCredentialsStore()
    
    @State private var loggedInUsername: String = ""
    
    // form input values
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    
    @State private var isSubmitting: Bool = false
    
    private func loadFromKeychain() {
        loggedInUsername = store.username ?? ""
    }
    
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
            
            showAlert(title: "Successfully logged in to Last.fm", message: "Signed in as \(session.name)")
            
            username = ""
            password = ""
            apiKey = ""
            apiSecret = ""
            
            loggedInUsername = session.name
        } catch {
            showAlert(title: "Connection failed", message: error.localizedDescription)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !loggedInUsername.isEmpty {
                    HStack(alignment: .center, spacing: 12) {
                        Image("LastFM")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(username)
                                .font(.headline)
                                .foregroundColor(Color("PrimaryText"))
                            
                            Text("1 million scrobbles")
                                .font(.subheadline)
                                .foregroundColor(Color("PrimaryText").opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                }
                
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
                
                PrimaryActionButton(
                    title: "Submit",
                    isLoading: isSubmitting,
                    isDisabled: false,
                    action: {
                        Task { await submit() }
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("last.fm")
        .onAppear {
            loadFromKeychain()
        }
    }
}
