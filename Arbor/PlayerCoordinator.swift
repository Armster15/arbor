//
//  PlayerCoordinator.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 11/11/25.
//

import SwiftUI

@MainActor
final class PlayerCoordinator: ObservableObject {
    @Published var isPresented: Bool = false

    func open()  { isPresented = true }
    func close() { isPresented = false }
}
