//
//  LoginView.swift
//  Epic Shots
//
//  Created by Max U on 3/25/25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        VStack {
            Spacer()
            if userManager.userName != nil {
                // If logged in, show HomeView with navigation
                HomeView()
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
                                    let name = fullName.givenName ?? "User"
                                    userManager.userName = name
                                }
                            }
                        case .failure(let error):
                            print("Login failed: \(error.localizedDescription)")
                        }
                    }
                )
                .frame(width: 200, height: 50)
            }
            Spacer()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
