//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import PythonKit

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
                let sys = Python.import("sys")
                print("Python \(sys.version_info.major).\(sys.version_info.minor)")
                print("Python Version: \(sys.version)")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
