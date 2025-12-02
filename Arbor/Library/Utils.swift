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

public func encodeURIComponent(_ str: String) -> String {
    let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
    let allowed = CharacterSet(charactersIn: unreserved)
    return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
}
