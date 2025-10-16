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
download()
"""

                _ = pythonRunSimpleString(code.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
