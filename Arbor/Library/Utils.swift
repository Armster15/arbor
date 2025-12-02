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
