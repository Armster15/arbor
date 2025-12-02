// maps an original url (e.g. a youtube url) to a local file path
struct LibraryLocalFile: Codable {
    var id: UUID
    var createdAt: Date
    
    var originalUrl: String
    var relativePath: String // path relative to Documents folder
        
    init(originalUrl: String, relativePath: String) {
        self.id = UUID()
        self.createdAt = Date()
        
        self.originalUrl = originalUrl
        self.relativePath = relativePath
    }
}

func getLibraryLocalFile(originalUrl: String) -> LibraryLocalFile? {
    if let saved = UserDefaults.standard.object(forKey: "LibraryLocalFile:" + originalUrl) as? Data {
        let decoder = JSONDecoder()
        if let data = try? decoder.decode(LibraryLocalFile.self, from: saved) {
            return data
        }
    }
    
    return nil
}

func saveLibraryLocalFile(_ libraryLocalFile: LibraryLocalFile) {
    let encoder = JSONEncoder()
    let encoded = try! encoder.encode(libraryLocalFile)
    UserDefaults.standard.set(encoded, forKey: "LibraryLocalFile:" + libraryLocalFile.originalUrl)
}

func deleteLibraryLocalFile(originalUrl: String) {
    UserDefaults.standard.removeObject(forKey: "LibraryLocalFile:" + originalUrl)
}

/// Looks up an existing locally saved audio file for the given original URL.
/// - Parameters:
///   - originalUrl: The original remote URL (e.g. YouTube URL).
///   - onMissingPhysicalFile: Optional hook that will be called if a mapping
///     exists but the underlying file is no longer present on disk.
/// - Returns: The absolute file system path if the file exists, otherwise `nil`.
func getLocalAudioFilePath(
    originalUrl: String,
    onMissingPhysicalFile: (() -> Void)? = nil
) -> String? {
    guard let localFile = getLibraryLocalFile(originalUrl: originalUrl) else {
        return nil
    }
    
    let docsURL = URL.documentsDirectory
    let fileURL = docsURL.appendingPathComponent(localFile.relativePath)
    let absolutePath = fileURL.path
    
    if FileManager.default.fileExists(atPath: absolutePath) {
        debugPrint("Reusing existing local file: \(absolutePath)")
        return absolutePath
    } else {
        // Local mapping exists but file is gone – clean up stale entry
        deleteLibraryLocalFile(originalUrl: originalUrl)
        onMissingPhysicalFile?()
        return nil
    }
}

/// Ensures there is a locally saved audio file for the given original URL.
///
/// If a valid existing file is already saved, its path is returned. Otherwise,
/// the file at `sourcePath` is copied into the app's Documents directory,
/// a new `LibraryLocalFile` mapping is created, and the new path is returned.
func ensureLocalAudioFile(
    originalUrl: String,
    sourcePath: String,
    title: String,
    artist: String,
    onMissingPhysicalFile: (() -> Void)? = nil
) -> String {
    if let existingPath = getLocalAudioFilePath(
        originalUrl: originalUrl,
        onMissingPhysicalFile: onMissingPhysicalFile
    ) {
        return existingPath
    }
    
    let sourceURL = URL(fileURLWithPath: sourcePath)
    let ext = sourceURL.pathExtension
    let timestamp = Int(Date().timeIntervalSince1970)
    let safeTitle = sanitizeForFilename(title)
    let safeArtist = sanitizeForFilename(artist)
    let newName = "\(safeTitle)-\(safeArtist)-\(timestamp).\(ext)"
    
    let docsURL = URL.documentsDirectory
    let newURL = docsURL.appendingPathComponent(newName)
    
    try? FileManager.default.copyItem(at: sourceURL, to: newURL)
    let absolutePath = newURL.path
    
    debugPrint("Saved audio file to more permanent location: \(absolutePath)")
    
    // Store only the path relative to the Documents directory
    let relativePath = absolutePath.replacingOccurrences(
        of: docsURL.path + "/",
        with: ""
    )
    let model = LibraryLocalFile(originalUrl: originalUrl, relativePath: relativePath)
    saveLibraryLocalFile(model)
    
    return absolutePath
}
