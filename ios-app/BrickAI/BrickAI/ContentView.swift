//
//  ContentView.swift
//  Epic Shots
//
//  Created by Max U on 3/22/25.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @State private var userName: String?

    var body: some View {
        VStack {
            Spacer()
            if let name = userName {
                Text("Hello \(name)")
                    .font(.largeTitle)
            } else {
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authResults):
                            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                if let fullName = appleIDCredential.fullName {
                                    let name = fullName.givenName ?? ""
                                    UserDefaults.standard.set(name, forKey: "userName")
                                    userName = name
                                }
                            }
                        case .failure(let error):
                            print("Authorization failed: \(error.localizedDescription)")
                        }
                    }
                )
                .frame(width: 200, height: 50)
            }
            Spacer()
        }
        .onAppear {
            if let name = UserDefaults.standard.string(forKey: "userName") {
                userName = name
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
