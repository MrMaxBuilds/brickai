// MARK: MODIFIED FILE - Views/LoginView.swift
// File: BrickAI/Views/LoginView.swift
// Added trigger for ImageDataManager

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager
    // MARK: <<< ADDED START >>>
    // Inject ImageDataManager from environment
    @EnvironmentObject var imageDataManager: ImageDataManager
    // MARK: <<< ADDED END >>>

    @State private var loginError: String? = nil
    @State private var isAuthenticating: Bool = false

    var body: some View {
        VStack {
            if userManager.isLoggedIn {
                 HomeView()
                     .transition(.opacity.combined(with: .scale))
                     // Pass environment objects down if needed by HomeView or its children
                     // Note: HomeView itself might not need them directly, but its destinations (Settings, ImageList) will
                     .environmentObject(userManager)
                     .environmentObject(imageDataManager) // Pass down imageDataManager
            } else {
                 // --- Login UI (No changes within this part) ---
                 Spacer()
                 Image("brickai-logo")
                     .resizable()
                     .aspectRatio(contentMode: .fit)
                    //  .frame(height: 60)
                     .padding(20)
                 Spacer()
                 Spacer()
                 if let errorMsg = loginError { Text(errorMsg).foregroundColor(.red).padding(.horizontal).multilineTextAlignment(.center).transition(.opacity).padding(.bottom) }
                 if isAuthenticating { ProgressView("Authenticating...").padding().transition(.opacity)
                 } else {
                     SignInWithAppleButton(.signIn, onRequest: { request in request.requestedScopes = [.fullName, .email] }, onCompletion: { result in
                         isAuthenticating = true; loginError = nil
                         switch result {
                         case .success(let authResults):
                             // ... (existing credential handling logic) ...
                             guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else { handleLoginError("Failed to process Apple credentials."); return }
                             let appleUserID = appleIDCredential.user
                             var currentUserName: String? = nil
                             if let fullName = appleIDCredential.fullName, let given = fullName.givenName, let family = fullName.familyName { let name = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines); if !name.isEmpty { currentUserName = name } }
                             if currentUserName == nil { currentUserName = KeychainService.loadString(forKey: kKeychainAccountUserName) ?? "User \(appleUserID.prefix(4))" }
                             guard let authCodeData = appleIDCredential.authorizationCode, let authCode = String(data: authCodeData, encoding: .utf8) else { handleLoginError("Could not retrieve authorization code from Apple."); return }

                             NetworkManager.exchangeAuthCode(authorizationCode: authCode) { exchangeResult in
                                 switch exchangeResult {
                                 case .success(let sessionToken):
                                     // Save credentials (UserManager updates isLoggedIn internally)
                                     userManager.saveCredentials(userName: currentUserName, userIdentifier: appleUserID, sessionToken: sessionToken)
                                     // Login state is updated by userManager, onChange below will trigger image fetch
                                     isAuthenticating = false
                                 case .failure(let error):
                                     handleLoginError(error.localizedDescription)
                                 }
                             }
                         case .failure(let error):
                             if (error as? ASAuthorizationError)?.code == .canceled { isAuthenticating = false; loginError = nil }
                             else { handleLoginError("Sign in with Apple failed: \(error.localizedDescription)") }
                         }
                     })
                     .signInWithAppleButtonStyle(.black).frame(width: 280, height: 45).padding().disabled(isAuthenticating).transition(.opacity.combined(with: .scale(scale: 0.9)))
                 }
                 Spacer()
                 // --- End Login UI ---
            }
        }
        .animation(.default, value: userManager.isLoggedIn)
        .animation(.easeInOut, value: loginError)
        .animation(.easeInOut, value: isAuthenticating)
        // MARK: <<< ADDED START >>>
        // Trigger image data preparation when login state changes or on initial appearance if already logged in
        .onChange(of: userManager.isLoggedIn) { _, newValue in
            if newValue {
                print("LoginView: User logged in (onChange). Preparing image data.")
                imageDataManager.prepareImageData()
            }
            // No action needed if newValue is false (logout handled elsewhere)
        }
        .onAppear {
             // Check if already logged in when the view appears
             if userManager.isLoggedIn {
                  print("LoginView: Already logged in (onAppear). Preparing image data.")
                  imageDataManager.prepareImageData()
             }
        }
        // MARK: <<< ADDED END >>>
    }

    private func handleLoginError(_ message: String) {
         DispatchQueue.main.async {
              self.loginError = message
              self.isAuthenticating = false
         }
    }
}

// Previews (kept as requested)
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock managers for preview if needed
        let mockUserManager = UserManager.shared // Use singleton or create specific mock
        let mockImageDataManager = ImageDataManager() // Use initializer or create specific mock

        LoginView()
            .environmentObject(mockUserManager)
            .environmentObject(mockImageDataManager)
    }
}
// MARK: END MODIFIED FILE - Views/LoginView.swift