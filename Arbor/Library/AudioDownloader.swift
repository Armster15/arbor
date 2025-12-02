//
//  AudioDownloader.swift
//  Arbor
//
//  Shared helper for downloading audio via the embedded Python runtime.
//

import Foundation

enum DownloadError: Error {
    case invalidSelection
    case emptyResult
    case invalidResponse
}

struct AudioDownloader {
    static func download(
        from url: String,
        completion: @escaping (Result<DownloadMeta, Error>) -> Void
    ) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(DownloadError.invalidSelection))
            return
        }

        // Escape backslashes and single quotes for safe embedding in Python string literal
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let code = """
from pytest_download import download
result = download('\(escaped)')
"""

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
        ) { result in
            guard let output = result, !output.isEmpty else {
                completion(.failure(DownloadError.emptyResult))
                return
            }

            guard let data = output.data(using: .utf8),
                  let meta = try? JSONDecoder().decode(DownloadMeta.self, from: data) else {
                completion(.failure(DownloadError.invalidResponse))
                return
            }

            completion(.success(meta))
        }
    }
}


