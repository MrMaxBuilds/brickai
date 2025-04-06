// File: web/src/app/api/auth/apple/callback/route.ts
// Updated to use @supabase/supabase-js

import { NextRequest, NextResponse } from 'next/server';
import jwt, { JwtHeader, SigningKeyCallback } from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
// import { sql } from '@vercel/postgres'; // Removed Vercel PG import
import { createClient } from '@supabase/supabase-js'; // Added Supabase client import

// --- Environment Variable Check ---
// Added Supabase variables, removed POSTGRES_URL if not used elsewhere
const requiredEnvVars = [
  'APPLE_BUNDLE_ID',
  'APPLE_SERVICE_ID', // Still needed for client_secret generation's 'sub' claim
  'APPLE_TEAM_ID',
  'APPLE_KEY_ID',
  'APPLE_PRIVATE_KEY',
  'SUPABASE_URL',               // Supabase URL
  'SUPABASE_SERVICE_ROLE_KEY', // Supabase Service Role Key (Secret!)
  'BACKEND_JWT_SECRET'
];

// Moved checks inside the handler to access env vars after they are potentially loaded
function checkEnvVars(): { valid: boolean, missing?: string } {
    for (const varName of requiredEnvVars) {
        if (!process.env[varName]) {
            console.error(`Missing required environment variable: ${varName}`);
            return { valid: false, missing: varName };
        }
    }
    return { valid: true };
}
// --- End Environment Variable Check ---


// --- Apple Public Key Retrieval (Remains the same) ---
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

// --- Generate Apple Client Secret (Remains the same - corrected 'sub' claim) ---
// Ensure APPLE_PRIVATE_KEY is correctly handled before this function is called
function generateClientSecret(privateKey: string): string {
    const now = Math.floor(Date.now() / 1000);
    const claims = {
        iss: process.env.APPLE_TEAM_ID as string,
        iat: now,
        exp: now + 60 * 60, // Expires in 1 hour
        aud: 'https://appleid.apple.com',
        sub: process.env.APPLE_BUNDLE_ID as string, // Correctly use Service ID here
    };

    const token = jwt.sign(claims, privateKey, {
        algorithm: 'ES256',
        header: {
            alg: 'ES256',
            kid: process.env.APPLE_KEY_ID as string,
        },
    });
    console.log("Generated Apple Client Secret with Service ID as subject.");
    return token;
}
// --- End Generate Apple Client Secret ---


// --- Main POST Handler for Code Exchange ---
export async function POST(req: NextRequest) {
  let authorizationCode: string;
  let appleUserId: string | null = null;
  let userEmail: string | null = null;

  // --- Check Environment Variables ---
  const envCheck = checkEnvVars();
  if (!envCheck.valid) {
    return NextResponse.json(
        { error: `Internal Server Configuration Error: Missing environment variable: ${envCheck.missing}` },
        { status: 500 }
    );
  }
  // Process private key only if checks pass
  const applePrivateKey = (process.env.APPLE_PRIVATE_KEY as string).replace(/\\n/g, '\n');
  const backendJwtSecret = process.env.BACKEND_JWT_SECRET as string;
  const supabaseUrl = process.env.SUPABASE_URL as string;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string;

  try {
    // --- Initialize Supabase Admin Client ---
    // Use Service Role Key for backend operations.
    // Disable session persistence as we are not managing Supabase auth sessions here.
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
        auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUrl: false
        }
    });
    console.log("Supabase service client initialized.");

    // --- 1. Get Authorization Code from Request Body ---
    const body = await req.json();
    authorizationCode = body.authorizationCode;

    if (!authorizationCode) {
      return NextResponse.json({ error: 'Missing authorizationCode in request body.' }, { status: 400 });
    }
    console.log("Received authorization code from client.");

    // --- 2. Generate Client Secret ---
    const clientSecret = generateClientSecret(applePrivateKey);

    // --- 3. Exchange Authorization Code for Tokens with Apple ---
    console.log("Exchanging authorization code with Apple...");
    const tokenResponse = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: process.env.APPLE_BUNDLE_ID as string, // Use iOS App's Bundle ID
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: 'authorization_code',
      }),
    });

    const tokenData = await tokenResponse.json();

    if (!tokenResponse.ok) {
      console.error('Apple Token Exchange Error:', tokenData);
      return NextResponse.json({ error: `Apple token exchange failed: ${tokenData.error || 'Unknown error'}` }, { status: tokenResponse.status });
    }
    console.log("Successfully exchanged code for tokens.");

    const appleRefreshToken = tokenData.refresh_token;
    const appleIdToken = tokenData.id_token;
    console.log("Apple ID Token received (length):", appleIdToken?.length ?? 0); // Avoid logging token

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
            audience: process.env.APPLE_BUNDLE_ID as string, // Correctly check against Bundle ID
          },
          (err, decodedPayload) => {
            if (err) { return reject(err); }
            if (!decodedPayload || typeof decodedPayload !== 'object') {
                return reject(new Error("Invalid decoded payload structure"));
            }
            resolve(decodedPayload as jwt.JwtPayload);
          }
        );
      });

      if (!decodedIdToken.sub) { throw new Error('Missing "sub" (user ID) claim in Apple ID token.'); }
      appleUserId = decodedIdToken.sub;
      userEmail = decodedIdToken.email ?? null;
      console.log(`Verified Apple User ID (sub): ${appleUserId}, Email: ${userEmail ?? 'N/A'}`);

    } catch (err: unknown) {
      console.error('Apple ID Token Verification Failed:', err instanceof Error ? err.message : 'Unknown error');
      let errorMessage = 'Unauthorized: Invalid Apple ID token.';
      if (err instanceof Error && err.name === 'TokenExpiredError') {
        errorMessage = 'Unauthorized: Apple ID token has expired.';
      }
      return NextResponse.json({ error: errorMessage }, { status: 401 });
    }

    // --- 5. Database Interaction using Supabase Client ---
    if (!appleUserId) { throw new Error("appleUserId is null after verification."); }

    console.log(`Upserting user and refresh token for Apple User ID: ${appleUserId} via Supabase`);
    try {
        // Use Supabase upsert method
        const { data: userData, error: dbError } = await supabase
            .from('users') // MAKE SURE 'users' matches your actual table name in Supabase
            .upsert(
                {
                    apple_user_id: appleUserId,         // Ensure column name matches schema
                    apple_refresh_token: appleRefreshToken ?? null, // Ensure column name matches schema
                    email: userEmail ?? null,           // Ensure column name matches schema
                    // 'updated_at' should be handled by DB default/trigger
                },
                {
                    onConflict: 'apple_user_id', // Specify the UNIQUE constraint column for conflict detection
                    // ignoreDuplicates: false // Default is false (ensures update if conflict)
                }
            )
            .select('id, apple_user_id, email') // Select the columns you want returned
            .single(); // We expect only one record (upsert returns the inserted/updated row)

        // Check for Supabase-specific errors
        if (dbError) {
            console.error('Supabase Upsert Error:', dbError);
            throw new Error(`Supabase error (${dbError.code}): ${dbError.message}`); // Throw a descriptive error
        }

        if (!userData) {
            // This case might happen if RLS prevents the return, though unlikely with service key
            throw new Error("Database upsert operation did not return user data.");
        }

        console.log("User upserted/found in DB via Supabase:", userData);
        appleUserId = userData.apple_user_id; // Reassign for consistency from returned data

    } catch (dbError: unknown) { // Changed from any to unknown
        console.error('Database Interaction Error:', dbError);
        return NextResponse.json({ 
            error: `Database operation failed: ${dbError instanceof Error ? dbError.message : 'Unknown database error'}` 
        }, { status: 500 });
    }

    // --- 6. Generate Backend Session Token (JWT - Remains the same) ---
    console.log("Generating backend session token...");
    const sessionTokenPayload = {
        iss: 'BrickAIBackend',
        sub: appleUserId,
        exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7), // 7 days validity
        iat: Math.floor(Date.now() / 1000),
    };
    const sessionToken = jwt.sign(sessionTokenPayload, backendJwtSecret, { algorithm: 'HS256' });
    console.log("Backend session token generated.");


    // --- 7. Return Session Token to Client (Remains the same) ---
    return NextResponse.json({
        message: 'Authentication successful',
        sessionToken: sessionToken,
        userId: appleUserId,
        email: userEmail
    });

  } catch (err: unknown) {
    console.error('Unhandled Authentication Error:', err);
    // Generic fallback error
    let message = 'Authentication process failed.';
    if (err instanceof Error) {
        message = err.message; // Use error message if available
    }
    return NextResponse.json({ error: message }, { status: 500 });
  }
}