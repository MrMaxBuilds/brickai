import SwiftUI
import AuthenticationServices
// Remove AVFoundation import if not directly used here anymore
// import AVFoundation

struct LoginView: View {
    @StateObject var userManager = UserManager.shared
    // No longer need CameraManager here if HomeView manages it

    var body: some View {
        // No NavigationStack needed here if HomeView provides its own
        VStack {
            if userManager.isLoggedIn {
                 HomeView()
                     .transition(.opacity.combined(with: .scale)) // Add transition effect
                     .environmentObject(userManager)
            } else {
                 Spacer()
                 Text("Welcome to BrickAI")
                     .font(.largeTitle)
                     .padding(.bottom, 40)

                 SignInWithAppleButton( /* ... Same configuration as before ... */
                     .signIn,
                     onRequest: { request in request.requestedScopes = [.fullName, .email] },
                     onCompletion: { result in
                          switch result {
                          case .success(let authResults):
                               guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
                               let appleUserID = appleIDCredential.user
                               var currentUserName: String? = nil
                               if let fullName = appleIDCredential.fullName {
                                   let name = (fullName.givenName ?? "") + " " + (fullName.familyName ?? "")
                                   let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                                   if !trimmedName.isEmpty { currentUserName = trimmedName }
                               }
                               if currentUserName == nil { currentUserName = KeychainService.loadString(forKey: kKeychainAccountUserName) ?? "User \(appleUserID.prefix(4))" }
                               guard let identityTokenData = appleIDCredential.identityToken else { return }

                               userManager.saveCredentials(
                                   userName: currentUserName,
                                   userIdentifier: appleUserID,
                                   identityTokenData: identityTokenData
                               )
                               // No need to manage camera here anymore

                          case .failure(let error):
                               print("Login failed: \(error.localizedDescription)")
                               userManager.clearUser()
                          }
                     }
                 )
                 .signInWithAppleButtonStyle(.black)
                 .frame(width: 280, height: 45)
                 .padding()

                 Spacer() // Push content to center
            } // End else (not logged in)
        } // End VStack
         // Animate the switch between Login content and HomeView
        .animation(.default, value: userManager.isLoggedIn)
    }
}

// Preview remains the same
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
