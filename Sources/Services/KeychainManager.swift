import Foundation
import Security

/// Manages secure storage and retrieval of credentials in the macOS Keychain.
/// Never stores tokens in UserDefaults or other insecure locations.
final class KeychainManager {
    
    static let shared = KeychainManager()
    
    private let service = "com.prtracker.app"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Saves a token securely to the Keychain.
    /// - Parameters:
    ///   - token: The access token to store.
    ///   - account: The account identifier (e.g., "github_pat" or "github_oauth").
    /// - Throws: `KeychainError` if the operation fails.
    func save(token: String, for account: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // Delete any existing item first
        try? delete(for: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    /// Retrieves a token from the Keychain.
    /// - Parameter account: The account identifier.
    /// - Returns: The stored token, or `nil` if not found.
    func retrieve(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    /// Deletes a token from the Keychain.
    /// - Parameter account: The account identifier.
    /// - Throws: `KeychainError` if the deletion fails.
    func delete(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
    
    /// Checks if a token exists for the given account.
    /// - Parameter account: The account identifier.
    /// - Returns: `true` if a token exists.
    func hasToken(for account: String) -> Bool {
        return retrieve(for: account) != nil
    }
}

// MARK: - Account Constants

extension KeychainManager {
    enum Account {
        static let gitHubToken = "github_token"
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode token data."
        case .saveFailed(let status):
            return "Failed to save to Keychain. Status: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain. Status: \(status)"
        }
    }
}
