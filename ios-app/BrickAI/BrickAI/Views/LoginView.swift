// File: BrickAI/Views/LoginView.swift
// Full Untruncated File

import SwiftUI
import AuthenticationServices
// Remove AVFoundation import if not directly used here anymore
// import AVFoundation

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager // Use EnvironmentObject if provided by parent
    // If LoginView is the absolute root, you might need @StateObject here instead
    // @StateObject private var userManager = UserManager.shared // Alternative if root

    // State for showing errors during login/auth code exchange
    @State private var loginError: String? = nil
    @State private var isAuthenticating: Bool = false // To show progress during exchange

    var body: some View {
        VStack {
            if userManager.isLoggedIn {
                 HomeView()
                     .transition(.opacity.combined(with: .scale)) // Add transition effect
                     // HomeView likely needs userManager too, ensure it's passed down
                     .environmentObject(userManager)
            } else {
                 // --- Login UI ---
                 Spacer()
                 Text("Welcome to BrickAI")
                     .font(.largeTitle)
                     .padding(.bottom, 40)

                 // Display error message if login fails
                 if let errorMsg = loginError {
                      Text(errorMsg)
                          .foregroundColor(.red)
                          .padding(.horizontal)
                          .multilineTextAlignment(.center)
                          .transition(.opacity) // Animate appearance
                          .padding(.bottom)
                 }

                 // Show spinner while exchanging code
                 if isAuthenticating {
                      ProgressView("Authenticating...")
                           .padding()
                           .transition(.opacity)
                 } else {
                     // --- Sign in Button ---
                     SignInWithAppleButton(
                         .signIn, // Use .signIn label
                         onRequest: { request in
                              // Request user's full name and email (Apple only provides on first sign-in)
                              request.requestedScopes = [.fullName, .email]
                              // Optionally add nonce for replay protection if backend supports checking it
                              // let nonce = generateNonce() // You'd need a nonce generation function
                              // request.nonce = sha256(nonce) // Hash the nonce
                              // saveNonce(nonce) // Store nonce locally to verify against id_token later (complex)
                         },
                         onCompletion: { result in
                              isAuthenticating = true // Start showing progress
                              loginError = nil      // Clear previous errors

                              switch result {
                              case .success(let authResults):
                                   print("LoginView: Apple Sign In Success.")
                                   guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                                        print("LoginView Error: Could not cast credential to ASAuthorizationAppleIDCredential.")
                                        handleLoginError("Failed to process Apple credentials.")
                                        return
                                   }

                                   // --- Extract Necessary Information ---
                                   let appleUserID = appleIDCredential.user // Stable user identifier
                                   var currentUserName: String? = nil
                                   // Get name only if provided (usually only first time)
                                   if let fullName = appleIDCredential.fullName,
                                      let given = fullName.givenName, let family = fullName.familyName {
                                       let name = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
                                       if !name.isEmpty { currentUserName = name }
                                   }
                                   // Fallback or retrieve stored name if not provided this time
                                   if currentUserName == nil {
                                        currentUserName = KeychainService.loadString(forKey: kKeychainAccountUserName) // Try loading existing
                                           ?? "User \(appleUserID.prefix(4))" // Simple fallback
                                   }

                                   // --- Get Authorization Code ---
                                   guard let authCodeData = appleIDCredential.authorizationCode,
                                         let authCode = String(data: authCodeData, encoding: .utf8) else {
                                        print("LoginView Error: Failed to get authorization code.")
                                        handleLoginError("Could not retrieve authorization code from Apple.")
                                        return
                                   }
                                   print("LoginView: Successfully received authorization code.")
                                   // --- REMOVED: Identity Token Handling ---
                                   // We no longer need the identityTokenData on the client side.
                                   // guard let identityTokenData = appleIDCredential.identityToken else { return }


                                   // --- Exchange Authorization Code with Backend ---
                                   print("LoginView: Exchanging authorization code with backend...")
                                   NetworkManager.exchangeAuthCode(authorizationCode: authCode) { exchangeResult in
                                        switch exchangeResult {
                                        case .success(let sessionToken):
                                             print("LoginView: Auth code exchange successful. Saving credentials.")
                                             // Save user info and the *backend session token*
                                             userManager.saveCredentials(
                                                 userName: currentUserName,
                                                 userIdentifier: appleUserID,
                                                 sessionToken: sessionToken // Pass the backend token
                                             )
                                             // Login state will update via @Published property in UserManager
                                             // No need to manually set isLoggedIn here
                                             isAuthenticating = false // Hide progress indicator

                                        case .failure(let error):
                                             print("LoginView Error: Auth code exchange failed: \(error.localizedDescription)")
                                             handleLoginError(error.localizedDescription) // Show error to user
                                        }
                                   } // End NetworkManager.exchangeAuthCode completion

                              case .failure(let error):
                                   // Handle Sign in with Apple UI level errors (e.g., user cancelled)
                                   // Ignore cancellation errors explicitly if desired
                                   if (error as? ASAuthorizationError)?.code == .canceled {
                                        print("LoginView: Apple Sign In cancelled by user.")
                                        isAuthenticating = false // Hide progress
                                        loginError = nil // Clear any previous errors
                                   } else {
                                        print("LoginView Error: Apple Sign In failed: \(error.localizedDescription)")
                                        handleLoginError("Sign in with Apple failed: \(error.localizedDescription)")
                                   }
                              }
                         }
                     ) // End SignInWithAppleButton
                     .signInWithAppleButtonStyle(.black) // Or .white, .whiteOutline
                     .frame(width: 280, height: 45)
                     .padding()
                     .disabled(isAuthenticating) // Disable button while authenticating
                     // Add transition for the button itself
                     .transition(.opacity.combined(with: .scale(scale: 0.9)))

                 } // End else (show sign in button)

                 Spacer() // Push content to center
                 // --- End Login UI ---
            } // End else (not logged in)
        } // End VStack
         // Animate the switch between Login content and HomeView, and error/progress indicators
        .animation(.default, value: userManager.isLoggedIn)
        .animation(.easeInOut, value: loginError)
        .animation(.easeInOut, value: isAuthenticating)
    } // End body

    // Helper function to handle setting error messages and stopping progress
    private func handleLoginError(_ message: String) {
         // Ensure UI updates happen on the main thread
         DispatchQueue.main.async {
              self.loginError = message
              self.isAuthenticating = false
         }
    }
}

// Preview remains the same
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(UserManager.shared) // Provide mock/shared manager for preview
    }
}
