import Foundation
import CryptoKit
import KeychainSwift

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
