// File: web/src/app/api/auth/refresh/route.ts
// Corrected TypeScript types AGAIN

import { NextRequest, NextResponse } from 'next/server';
import jwt, { JwtHeader, SigningKeyCallback, VerifyOptions, JwtPayload } from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { createClient } from '@supabase/supabase-js';

// --- Environment Variable Check (Same as before) ---
const requiredEnvVars = [
  'APPLE_BUNDLE_ID',
  'APPLE_SERVICE_ID',
  'APPLE_TEAM_ID',
  'APPLE_KEY_ID',
  'APPLE_PRIVATE_KEY',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'BACKEND_JWT_SECRET'
];

function checkEnvVars(): { valid: boolean, missing?: string } {
    for (const varName of requiredEnvVars) {
        if (!process.env[varName]) {
            console.error(`Refresh Route: Missing required environment variable: ${varName}`);
            return { valid: false, missing: varName };
        }
    }
    if (!process.env.APPLE_PRIVATE_KEY || !(process.env.APPLE_PRIVATE_KEY as string).includes('-----BEGIN PRIVATE KEY-----')) {
        console.error('Refresh Route: APPLE_PRIVATE_KEY environment variable seems malformed or missing.');
        return { valid: false, missing: 'APPLE_PRIVATE_KEY (Malformed)' };
    }
    return { valid: true };
}
// --- End Environment Variable Check ---


// --- Apple Public Key Retrieval (Same as before) ---
const appleClient = jwksClient({
  jwksUri: 'https://appleid.apple.com/auth/keys',
  cache: true,
  cacheMaxEntries: 5,
  cacheMaxAge: 60 * 60 * 1000, // 1 hour
});

function getAppleSigningKey(header: JwtHeader, callback: SigningKeyCallback): void {
  if (!header.kid) { return callback(new Error('No kid found in Apple JWT header')); }
  appleClient.getSigningKey(header.kid, (err, key) => {
    if (err) { console.error("Error fetching Apple signing key:", err); return callback(err); }
    const signingKey = key?.getPublicKey();
    if (!signingKey) { return callback(new Error('Could not get public key from fetched signing key.')); }
    callback(null, signingKey);
  });
}
// --- End Apple Public Key Retrieval ---

// --- Generate Apple Client Secret (Same as before) ---
function generateClientSecret(privateKey: string): string {
    const now = Math.floor(Date.now() / 1000);
    const claims = {
        iss: process.env.APPLE_TEAM_ID as string, iat: now, exp: now + 60 * 60,
        aud: 'https://appleid.apple.com',
        // NOTE: Per Apple docs, 'sub' should likely be APPLE_SERVICE_ID here. Using BUNDLE_ID based on user state.
        sub: process.env.APPLE_BUNDLE_ID as string,
    };
    const token = jwt.sign(claims, privateKey, {
        algorithm: 'ES256', header: { alg: 'ES256', kid: process.env.APPLE_KEY_ID as string },
    });
    return token;
}
// --- End Generate Apple Client Secret ---


// --- Main POST Handler for Refreshing Backend Session Token ---
export async function POST(req: NextRequest) {
  let appleUserId: string; // Changed: Initialize later after verification
  let storedAppleRefreshToken: string; // Changed: Initialize later

  // --- Check Environment Variables ---
  const envCheck = checkEnvVars();
  if (!envCheck.valid) {
    return NextResponse.json( { error: `Internal Server Configuration Error: Missing environment variable: ${envCheck.missing}` }, { status: 500 } );
  }
  const applePrivateKey = (process.env.APPLE_PRIVATE_KEY as string).replace(/\\n/g, '\n');
  const backendJwtSecret = process.env.BACKEND_JWT_SECRET as string;
  const supabaseUrl = process.env.SUPABASE_URL as string;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string;

  try {
    // --- 1. Get Expired Backend Token and Extract User ID ---
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized: Missing Authorization header.' }, { status: 401 });
    }
    const expiredToken = authHeader.substring(7);

    try {
        const decoded = jwt.verify(
            expiredToken, backendJwtSecret,
            { algorithms: ['HS256'], issuer: 'BrickAIBackend', ignoreExpiration: true }
        );

        // **REVISED FIX 1 START: Check type and 'sub' property robustly**
        if (typeof decoded === 'object' && decoded !== null && typeof decoded.sub === 'string') {
            appleUserId = decoded.sub; // Assign only if check passes
        } else {
            // Throw error if 'decoded' is not an object or 'sub' is missing/not a string
            throw new Error('Invalid token payload structure or missing/invalid sub claim.');
        }
        // **REVISED FIX 1 END**

        console.log(`Refresh Route: Verified expired token signature for Apple User ID: ${appleUserId}`);

    } catch (err: unknown) {
        console.error('Refresh Route: Invalid backend token provided:', err instanceof Error ? err.message : 'Unknown error');
        let errorMessage = 'Unauthorized: Invalid token provided for refresh.';
        if (err instanceof Error && err.name === 'JsonWebTokenError') {
             errorMessage = 'Unauthorized: Malformed token provided for refresh.';
        }
        return NextResponse.json({ error: errorMessage }, { status: 401 });
    }

    // --- 2. Initialize Supabase Admin Client (code unchanged) ---
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
        auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });

    // --- 3. Retrieve Stored Apple Refresh Token from Database (code unchanged) ---
    console.log(`Refresh Route: Fetching Apple refresh token for user: ${appleUserId}`);
    try {
        const { data: userData, error: fetchError } = await supabase
            .from('users').select('apple_refresh_token').eq('apple_user_id', appleUserId).single();

        if (fetchError) { throw new Error(`Supabase error (${fetchError.code}): ${fetchError.message}`); }
        if (!userData) { return NextResponse.json({ error: 'Unauthorized: User not found.' }, { status: 401 }); }
        if (!userData.apple_refresh_token) { return NextResponse.json({ error: 'Unauthorized: Refresh token not available.' }, { status: 401 }); }

        storedAppleRefreshToken = userData.apple_refresh_token; // Assign here
        console.log(`Refresh Route: Retrieved Apple refresh token for user: ${appleUserId}`);

    } catch (dbError: unknown) {
        console.error('Refresh Route: Database Error fetching refresh token:', 
          dbError instanceof Error ? dbError.message : 'Unknown error');
        return NextResponse.json({ 
          error: `Database operation failed: ${dbError instanceof Error ? dbError.message : 'Unknown database error'}` 
        }, { status: 500 });
    }

    // --- 4. Generate NEW Client Secret (code unchanged) ---
    const clientSecret = generateClientSecret(applePrivateKey);

    // --- 5. Exchange Apple Refresh Token for New Tokens with Apple ---
    console.log("Refresh Route: Exchanging Apple refresh token with Apple...");
    let newAppleIdToken: string | undefined;
    let newAppleRefreshToken: string | undefined;

    // No need for !storedAppleRefreshToken check here as step 3 guarantees it's assigned if we reach here.

    try {
        const tokenResponse = await fetch('https://appleid.apple.com/auth/token', {
            method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                client_id: process.env.APPLE_BUNDLE_ID as string, client_secret: clientSecret,
                grant_type: 'refresh_token', refresh_token: storedAppleRefreshToken, // Known to be string here
            }),
        });
        const tokenData = await tokenResponse.json();

        if (!tokenResponse.ok) {
            console.error('Refresh Route: Apple Token Refresh Error:', tokenData);
            if (tokenData.error === 'invalid_grant') {
                 console.warn(`Refresh Route: Apple refresh token invalid_grant for user ${appleUserId}. Token might be revoked.`);
                 try { await supabase.from('users').update({ apple_refresh_token: null }).eq('apple_user_id', appleUserId); }
                 catch(clearError: unknown) {
                   console.error(`Refresh Route: Failed to clear invalid refresh token for user ${appleUserId}:`, 
                     clearError instanceof Error ? clearError.message : 'Unknown error'); 
                 }
                 return NextResponse.json({ error: 'Unauthorized: Apple refresh token invalid or revoked.' }, { status: 401 });
            }
            return NextResponse.json({ error: `Apple token refresh failed: ${tokenData.error || 'Unknown error'}` }, { status: tokenResponse.status });
        }
        console.log("Refresh Route: Successfully exchanged Apple refresh token.");
        newAppleIdToken = tokenData.id_token; newAppleRefreshToken = tokenData.refresh_token;
        if (!newAppleIdToken) { throw new Error("Apple did not return a new id_token during refresh."); }

    } catch (exchangeError: unknown) {
         console.error('Refresh Route: Error during fetch to Apple /auth/token:', 
           exchangeError instanceof Error ? exchangeError.message : 'Unknown error');
         return NextResponse.json({ 
           error: `Failed to communicate with Apple for token refresh: ${exchangeError instanceof Error ? exchangeError.message : 'Unknown error'}` 
         }, { status: 502 });
    }

    // --- 6. Verify the NEW Apple ID Token ---
    console.log("Refresh Route: Verifying new Apple ID Token...");
    try {
        // Use Promise<void> as we only care about success/failure of verification here
        await new Promise<void>((resolve, reject) => {
            jwt.verify(
                newAppleIdToken!, getAppleSigningKey,
                { algorithms: ['RS256'], issuer: 'https://appleid.apple.com', audience: process.env.APPLE_BUNDLE_ID as string } as VerifyOptions,
                (err, decodedPayload) => {
                    const payload = decodedPayload as JwtPayload;
                    if (err) { return reject(err); }

                    // **REVISED FIX 1 (Verification) START: Check type and 'sub' property robustly**
                    if (typeof decodedPayload !== 'object' || decodedPayload === null || typeof payload.sub !== 'string') {
                        return reject(new Error("Invalid ID token payload structure or missing/invalid 'sub' claim"));
                    }
                    // Check 'sub' matches original user ID (which is now guaranteed non-null)
                    if (payload.sub !== appleUserId) {
                         return reject(new Error(`ID token 'sub' (${payload.sub}) does not match original user (${appleUserId})`));
                    }
                    // **REVISED FIX 1 (Verification) END**

                    // If all checks pass, resolve the promise
                    resolve();
                }
            );
        });
        console.log(`Refresh Route: Verified new Apple ID token for user: ${appleUserId}`); // Log original ID is fine

    } catch (err: unknown) {
        console.error('Refresh Route: New Apple ID Token Verification Failed:', err instanceof Error ? err.message : 'Unknown error');
        let errorMessage = 'Unauthorized: Invalid new Apple ID token received.';
        if (err instanceof Error && err.name === 'TokenExpiredError') { errorMessage = 'Unauthorized: New Apple ID token is already expired.'; }
        return NextResponse.json({ error: errorMessage }, { status: 401 });
    }

    // --- 7. Update Stored Refresh Token (if necessary - code unchanged) ---
    if (newAppleRefreshToken && newAppleRefreshToken !== storedAppleRefreshToken) {
        console.log(`Refresh Route: Apple issued a new refresh token for user ${appleUserId}. Updating database.`);
        try {
            const { error: updateError } = await supabase.from('users').update({ apple_refresh_token: newAppleRefreshToken }).eq('apple_user_id', appleUserId);
            if (updateError) { console.error(`Refresh Route: Failed to update new Apple refresh token in DB for user ${appleUserId}:`, updateError.message); }
            else { console.log(`Refresh Route: Successfully updated new Apple refresh token for user ${appleUserId}.`); }
        } catch (dbUpdateError: unknown) {
          console.error(`Refresh Route: Exception during DB update for new refresh token for user ${appleUserId}:`, 
            dbUpdateError instanceof Error ? dbUpdateError.message : 'Unknown error'); 
        }
    }

    // --- 8. Generate NEW Backend Session Token (code unchanged) ---
    console.log("Refresh Route: Generating new backend session token...");
    const newSessionTokenPayload = {
        iss: 'BrickAIBackend', sub: appleUserId,
        // exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7), // 7 Days
        exp: Math.floor(Date.now() / 1000) + (30), // 30 Seconds
        iat: Math.floor(Date.now() / 1000),
    };
    const newSessionToken = jwt.sign(newSessionTokenPayload, backendJwtSecret, { algorithm: 'HS256' });
    console.log("Refresh Route: New backend session token generated.");

    // --- 9. Return NEW Session Token to Client (code unchanged) ---
    return NextResponse.json({ sessionToken: newSessionToken });

  } catch (err: unknown) {
    console.error('Refresh Route: Unhandled Error:', err);
    let message = 'Session refresh process failed.';
    if (err instanceof Error) { message = err.message; }
    return NextResponse.json({ error: message }, { status: 500 });
  }
}