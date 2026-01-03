import Foundation
import CryptoKit
import KeychainSwift
import ScrobbleKit

public struct LastFMCredentialsStore {
    private let keychain = KeychainSwift()

    enum Key {
        static let username = "lastfm.username"
        static let apiKey = "lastfm.apiKey"
        static let apiSecret = "lastfm.apiSecret"
        static let sessionKey = "lastfm.sessionKey"
    }

    enum StoreError: Error, LocalizedError {
        case keychainSetFailed(key: String)
        case keychainDeleteFailed(key: String)

        var errorDescription: String? {
            switch self {
            case .keychainSetFailed(let key):
                return "Failed to save '\(key)' to Keychain."
            case .keychainDeleteFailed(let key):
                return "Failed to delete '\(key)' from Keychain."
            }
        }
    }

    var username: String? { keychain.get(Key.username) }
    var apiKey: String? { keychain.get(Key.apiKey) }
    var apiSecret: String? { keychain.get(Key.apiSecret) }
    var sessionKey: String? { keychain.get(Key.sessionKey) }

    func save(username: String, apiKey: String, apiSecret: String, sessionKey: String) throws {
        let access: KeychainSwiftAccessOptions = .accessibleAfterFirstUnlock

        guard keychain.set(username, forKey: Key.username, withAccess: access) else {
            throw StoreError.keychainSetFailed(key: Key.username)
        }
        guard keychain.set(apiKey, forKey: Key.apiKey, withAccess: access) else {
            throw StoreError.keychainSetFailed(key: Key.apiKey)
        }
        guard keychain.set(apiSecret, forKey: Key.apiSecret, withAccess: access) else {
            throw StoreError.keychainSetFailed(key: Key.apiSecret)
        }
        guard keychain.set(sessionKey, forKey: Key.sessionKey, withAccess: access) else {
            throw StoreError.keychainSetFailed(key: Key.sessionKey)
        }
    }

    func clear() throws {
        guard keychain.delete(Key.username) else {
            throw StoreError.keychainDeleteFailed(key: Key.username)
        }
        guard keychain.delete(Key.apiKey) else {
            throw StoreError.keychainDeleteFailed(key: Key.apiKey)
        }
        guard keychain.delete(Key.apiSecret) else {
            throw StoreError.keychainDeleteFailed(key: Key.apiSecret)
        }
        guard keychain.delete(Key.sessionKey) else {
            throw StoreError.keychainDeleteFailed(key: Key.sessionKey)
        }
    }
}

let SROBBLING_ENABLED_KEY = "lastFmScrobblingEnabled"

@MainActor
final class LastFMSession: ObservableObject {
    @Published public private(set) var username: String = ""
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var manager: SBKManager? = nil
    @Published public var isScrobblingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isScrobblingEnabled, forKey: SROBBLING_ENABLED_KEY)
        }
    }
    
    private let store = LastFMCredentialsStore()
    
    init() {
        if UserDefaults.standard.object(forKey: SROBBLING_ENABLED_KEY) == nil {
            UserDefaults.standard.set(true, forKey: SROBBLING_ENABLED_KEY)
        }
        isScrobblingEnabled = UserDefaults.standard.bool(forKey: SROBBLING_ENABLED_KEY)
        
        restoreFromKeychain()
    }
    
    public func restoreFromKeychain() {
        guard let username = store.username?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty,
              let apiKey = store.apiKey,
              let apiSecret = store.apiSecret,
              let sessionKey = store.sessionKey else {
            clearLocalState()
            return
        }
        
        let manager = SBKManager(apiKey: apiKey, secret: apiSecret)
        manager.setSessionKey(sessionKey)
        
        self.username = username
        self.manager = manager
        self.isAuthenticated = true
    }
    
    func signIn(username: String, password: String, apiKey: String, apiSecret: String) async throws {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let manager = SBKManager(apiKey: trimmedApiKey, secret: trimmedApiSecret)
        let session = try await manager.startSession(username: trimmedUsername, password: trimmedPassword)
        
        try store.save(
            username: session.name,
            apiKey: trimmedApiKey,
            apiSecret: trimmedApiSecret,
            sessionKey: session.key
        )
        
        self.username = session.name
        self.manager = manager
        self.isAuthenticated = true
    }
    
    func signOut() throws {
        try store.clear()
        manager?.signOut()
        isScrobblingEnabled = true
        clearLocalState()
    }
    
    private func clearLocalState() {
        username = ""
        isAuthenticated = false
        manager = nil
        isScrobblingEnabled = true
    }
}
