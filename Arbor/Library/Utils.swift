public func isValidURL(_ string: String) -> Bool {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercased = trimmed.lowercased()

    if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
        if let _ = URL(string: lowercased) {
            return true
        }
    }

    return false
}

public func formattedTime(_ seconds: Double) -> String {
    guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
    let s = Int(seconds.rounded())
    let mins = s / 60
    let secs = s % 60
    return String(format: "%d:%02d", mins, secs)
}

public func sanitizeForFilename(_ string: String) -> String {
    // Remove or replace characters that are unsafe for filenames
    let unsafeCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
    let sanitized = string.components(separatedBy: unsafeCharacters).joined(separator: "_")
    
    // Also replace newlines and trim whitespace
    let cleaned = sanitized
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Limit length to avoid extremely long filenames (max 100 chars per field)
    return String(cleaned.prefix(100))
}
