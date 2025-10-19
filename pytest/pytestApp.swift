//
//  pytestApp.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation

@main
struct pytestApp: App {
    init() {
        _ = start_python_runtime(CommandLine.argc, CommandLine.unsafeArgv)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
