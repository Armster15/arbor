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
                if let version = pythonGetModuleAttrString("yt_dlp.version", "__version__") {
                    print("yt_dlp version: \(version)")
                } else {
                    print("Failed to get yt_dlp version")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
