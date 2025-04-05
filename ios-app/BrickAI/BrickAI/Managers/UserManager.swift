//
//  UserManager.swift
//  Epic Shots
//
//  Created by Max U on 3/25/25.
//

import Foundation

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var userName: String? {
        didSet {
            if let name = userName {
                UserDefaults.standard.set(name, forKey: "userName")
            } else {
                UserDefaults.standard.removeObject(forKey: "userName")
            }
        }
    }
    
    private init() {
        // Load saved username when the app starts
        self.userName = UserDefaults.standard.string(forKey: "userName")
    }
}
