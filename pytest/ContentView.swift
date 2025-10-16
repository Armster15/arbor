//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI


struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Button("Click for Swift") {
                print("Pure native logs")
            }
            
            Button("Click for Python") {
                let code = """
from pytest_download import download
audio_fp = download()
"""

                if let audioPath = pythonExecAndGetString(
                    code.trimmingCharacters(in: .whitespacesAndNewlines), 
                    // string variable to return the value of to swift
                    "audio_fp"
                ) {
                    print("Downloaded file: \(audioPath)")
                } else {
                    print("Failed to fetch audio_fp from Python")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
