// File: web/src/app/api/auth/apple/callback/route.ts
import { NextRequest, NextResponse } from 'next/server';
import jwt, { JwtHeader, SigningKeyCallback } from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { sql } from '@vercel/postgres'; // Vercel Postgres client

// --- Environment Variable Check ---
// Add new required variables for Apple auth and database
const requiredEnvVars = [
  'APPLE_BUNDLE_ID',
  'APPLE_SERVICE_ID', // Your Services ID (often same as Bundle ID)
  'APPLE_TEAM_ID',    // Your Apple Developer Team ID
  'APPLE_KEY_ID',     // The Key ID for your Sign in with Apple private key
  'APPLE_PRIVATE_KEY',// The content of your .p8 private key file
  'POSTGRES_URL',     // Vercel Postgres connection string
  'BACKEND_JWT_SECRET' // A strong secret for signing *your* session tokens
];

function checkEnvVars(): boolean {
    for (const varName of requiredEnvVars) {
        if (!process.env[varName]) {
            // Critical error, stop serverless function execution
            console.error(`Missing required environment variable: ${varName}`);
            // In a real app, you might throw an error or return a generic server error
            // For simplicity here, we'll return a 500, but ideally the function fails deployment
            // if these are missing.
            return false;
        }
    }
    return true;
}
// Replace newline characters in the private key if stored in env var
const applePrivateKey = (process.env.APPLE_PRIVATE_KEY as string).replace(/\\n/g, '\n');
const backendJwtSecret = process.env.BACKEND_JWT_SECRET as string;
// --- End Environment Variable Check ---

// --- Apple Public Key Retrieval (Same as before) ---
const appleClient = jwksClient({
  jwksUri: 'https://appleid.apple.com/auth/keys',
  cache: true,
  cacheMaxEntries: 5,
  cacheMaxAge: 60 * 60 * 1000, // 1 hour
});

function getAppleSigningKey(header: JwtHeader, callback: SigningKeyCallback): void {
  if (!header.kid) {
    return callback(new Error('No kid found in Apple JWT header'));
  }
  appleClient.getSigningKey(header.kid, (err, key) => {
    if (err) {
      console.error("Error fetching Apple signing key:", err);
      return callback(err);
    }
    const signingKey = key?.getPublicKey();
    if (!signingKey) {
        return callback(new Error('Could not get public key from fetched signing key.'));
    }
    callback(null, signingKey);
  });
}
// --- End Apple Public Key Retrieval ---

// --- Generate Apple Client Secret ---
function generateClientSecret(): string {
    const now = Math.floor(Date.now() / 1000);
    const claims = {
        iss: process.env.APPLE_TEAM_ID as string,
        iat: now,
        exp: now + 60 * 60, // Expires in 1 hour, max allowed by Apple is 6 months
        aud: 'https://appleid.apple.com',
        sub: process.env.APPLE_BUNDLE_ID as string, // Your Services ID
    };

    const token = jwt.sign(claims, applePrivateKey, {
        algorithm: 'ES256', // Apple requires ES256
        header: {
            alg: 'ES256',
            kid: process.env.APPLE_KEY_ID as string, // Your Private Key ID
        },
    });
    console.log("Generated Apple Client Secret."); // Avoid logging the secret itself
    return token;
}
// --- End Generate Apple Client Secret ---


// --- Main POST Handler for Code Exchange ---
export async function POST(req: NextRequest) {
  let authorizationCode: string;
  let appleUserId: string | null = null;
  let userEmail: string | null = null;

  if (!checkEnvVars()) {
    return NextResponse.json(
        { error: `Internal Server Configuration Error: Missing environment variables` },
        { status: 500 }
    );
  }

  try {
    // --- 1. Get Authorization Code from Request Body ---
    const body = await req.json();
    authorizationCode = body.authorizationCode;

    if (!authorizationCode) {
      return NextResponse.json({ error: 'Missing authorizationCode in request body.' }, { status: 400 });
    }
    console.log("Received authorization code from client.");

    // --- 2. Generate Client Secret ---
    const clientSecret = generateClientSecret();

    // --- 3. Exchange Authorization Code for Tokens with Apple ---
    console.log("Exchanging authorization code with Apple...");
    const tokenResponse = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: process.env.APPLE_BUNDLE_ID as string, // Your Services ID
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: 'authorization_code',
        // redirect_uri: 'YOUR_REDIRECT_URI' // Required if configured in your Services ID
      }),
    });

    const tokenData = await tokenResponse.json();

    if (!tokenResponse.ok) {
      console.error('Apple Token Exchange Error:', tokenData);
      return NextResponse.json({ error: `Apple token exchange failed: ${tokenData.error || 'Unknown error'}` }, { status: tokenResponse.status });
    }
    console.log("Successfully exchanged code for tokens.");

    const appleRefreshToken = tokenData.refresh_token; // Store this securely!
    const appleIdToken = tokenData.id_token; // Verify this
    console.log("Apple ID Token:", appleIdToken);

    // --- 4. Verify the Apple ID Token ---
    console.log("Verifying Apple ID Token...");
    try {
      const decodedIdToken = await new Promise<jwt.JwtPayload>((resolve, reject) => {
        jwt.verify(
          appleIdToken,
          getAppleSigningKey,
          {
            algorithms: ['RS256'],
            issuer: 'https://appleid.apple.com',
            audience: process.env.APPLE_BUNDLE_ID as string, // Use Service ID here
            // Nonce checking would happen here if you passed one in the initial auth request
          },
          (err, decodedPayload) => {
            if (err) {
              return reject(err);
            }
            if (!decodedPayload || typeof decodedPayload !== 'object') {
                return reject(new Error("Invalid decoded payload structure"));
            }
            resolve(decodedPayload as jwt.JwtPayload);
          }
        );
      });

      if (!decodedIdToken.sub) {
        throw new Error('Missing "sub" (user ID) claim in Apple ID token.');
      }
      appleUserId = decodedIdToken.sub;
      userEmail = decodedIdToken.email ?? null; // Email might not always be present
      // Note: Full name is typically only in the *initial* ASAuthorizationAppleIDCredential, not the id_token from the token endpoint.
      // You'd need to have captured it on the client during login and potentially pass it alongside the auth code if needed here.

      console.log(`Verified Apple User ID (sub): ${appleUserId}, Email: ${userEmail ?? 'N/A'}`);

    } catch (err: unknown) {
      console.error('Apple ID Token Verification Failed:', err instanceof Error ? err.message : 'Unknown error');
      // Handle specific JWT errors if needed (e.g., TokenExpiredError)
      let errorMessage = 'Unauthorized: Invalid Apple ID token.';
      if (err instanceof Error && err.name === 'TokenExpiredError') {
        errorMessage = 'Unauthorized: Apple ID token has expired.';
      }
      return NextResponse.json({ error: errorMessage }, { status: 401 });
    }

    // --- 5. Database Interaction: Find or Create User, Store Refresh Token ---
    if (!appleUserId) {
         // Should not happen if verification passed, but safeguard
         throw new Error("appleUserId is null after verification.");
    }
    console.log(`Upserting user and refresh token for Apple User ID: ${appleUserId}`);
    try {
        // Use ON CONFLICT to handle both INSERT and UPDATE in one go (Upsert)
        // IMPORTANT: Ensure your table and constraints are set up correctly in Vercel Postgres.
        // Example Schema:
        // CREATE TABLE users (
        //   id SERIAL PRIMARY KEY,
        //   apple_user_id TEXT UNIQUE NOT NULL,
        //   apple_refresh_token TEXT,
        //   email TEXT,
        //   full_name TEXT, -- If you decide to store it
        //   created_at TIMESTAMPTZ DEFAULT NOW(),
        //   updated_at TIMESTAMPTZ DEFAULT NOW()
        // );
        // CREATE INDEX idx_users_apple_user_id ON users(apple_user_id);
        // -- Trigger to update updated_at timestamp (optional but good practice)
        // CREATE OR REPLACE FUNCTION update_updated_at_column()
        // RETURNS TRIGGER AS $$
        // BEGIN
        //    NEW.updated_at = now();
        //    RETURN NEW;
        // END;
        // $$ language 'plpgsql';
        // CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

        const result = await sql`
            INSERT INTO users (apple_user_id, apple_refresh_token, email)
            VALUES (${appleUserId}, ${appleRefreshToken ?? null}, ${userEmail ?? null})
            ON CONFLICT (apple_user_id)
            DO UPDATE SET
                apple_refresh_token = EXCLUDED.apple_refresh_token,
                email = COALESCE(EXCLUDED.email, users.email), -- Keep existing email if new one is null
                updated_at = NOW()
            RETURNING id, apple_user_id, email; -- Return needed info
        `;

        if (result.rows.length === 0) {
            throw new Error("Database operation failed to return user data.");
        }
        const dbUser = result.rows[0];
        console.log("User upserted/found in DB:", dbUser);
        // Ensure appleUserId is definitely set from DB record for consistency
        appleUserId = dbUser.apple_user_id;


    } catch (dbError: unknown) {
        console.error('Database Error:', dbError);
        return NextResponse.json({ error: 'Database operation failed.' }, { status: 500 });
    }

    // --- 6. Generate Backend Session Token (JWT) ---
    console.log("Generating backend session token...");
    const sessionTokenPayload = {
        iss: 'BrickAIBackend', // Your backend identifier
        sub: appleUserId,       // The verified Apple User ID
        // Add other claims as needed (e.g., roles, session ID)
        // Set an appropriate expiration time for your session token
        exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7), // Example: 7 days
        iat: Math.floor(Date.now() / 1000),
    };

    const sessionToken = jwt.sign(sessionTokenPayload, backendJwtSecret, { algorithm: 'HS256' });
    console.log("Backend session token generated.");


    // --- 7. Return Session Token to Client ---
    return NextResponse.json({
        message: 'Authentication successful',
        sessionToken: sessionToken, // Send your backend token to the client
        userId: appleUserId,      // Optionally send user ID back
        email: userEmail          // Optionally send email back
    });

  } catch (err: unknown) {
    console.error('Authentication Error:', err);
    return NextResponse.json({ error: 'Authentication process failed.' }, { status: 500 });
  }
}