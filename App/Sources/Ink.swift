import SwiftUI
import UIKit

/// Blood and brass. One palette. Dark is the only scheme.
enum Ink {
    static let ground = Color(hex: 0x140C0E)
    static let card = Color(hex: 0x231418)
    static let words = Color(hex: 0xF0E4D4)
    static let muted = Color(hex: 0xC4A99A)
    static let brass = Color(hex: 0xC9A15B)
    static let wine = Color(hex: 0x8B2E3A)
    static let line = Color(hex: 0x4A2A30)

    static func install() {
        let ground = UIColor(Ink.ground)
        let card = UIColor(Ink.card)
        let words = UIColor(Ink.words)
        UITableView.appearance().backgroundColor = ground
        UITableViewCell.appearance().backgroundColor = card
        UICollectionView.appearance().backgroundColor = ground
        UITextField.appearance().keyboardAppearance = .dark
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = ground
        nav.titleTextAttributes = [.foregroundColor: words]
        nav.largeTitleTextAttributes = [.foregroundColor: words]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = ground
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().unselectedItemTintColor = UIColor(Ink.muted)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
