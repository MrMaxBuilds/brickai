import { NextRequest, NextResponse } from 'next/server';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';
import { UserInfo } from '@/user/types';

// --- Environment Variable List ---
const requiredEnvVars = [
  'BACKEND_JWT_SECRET',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];

// --- Hardcoded IAP Product ID to Credits Map ---
const iapProductCreditsMap: Record<string, number> = {
  'com.NEXTAppDevelopment.brickai.5dollars': 30,
  // Add more product IDs and their corresponding credit amounts here
};

// Helper function to check environment variables (can be shared if in a utils file)
function checkEnvVars(vars: string[], routeName?: string): { valid: boolean; missing?: string } {
  const prefix = routeName ? `${routeName}: ` : '';
  for (const varName of vars) {
    if (!process.env[varName]) {
      console.error(`${prefix}Missing required environment variable: ${varName}`);
      return { valid: false, missing: varName };
    }
  }
  return { valid: true };
}

export async function POST(req: NextRequest) {
  const routeName = 'Add Credits Route';

  // 1. Environment Variable Check
  const envCheck = checkEnvVars(requiredEnvVars, routeName);
  if (!envCheck.valid) {
    return NextResponse.json({ error: `Internal Server Configuration Error: Missing env var: ${envCheck.missing}` }, { status: 500 });
  }

  const backendJwtSecret = process.env.BACKEND_JWT_SECRET!;
  const supabaseUrl = process.env.SUPABASE_URL!;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  let appleUserId: string;

  try {
    // 2. Verify Backend Session Token
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized: Missing or invalid Authorization header.' }, { status: 401 });
    }
    const sessionToken = authHeader.substring(7);
    try {
      const decoded = jwt.verify(sessionToken, backendJwtSecret, { algorithms: ['HS256'], issuer: 'BrickAIBackend' });
      if (typeof decoded === 'object' && decoded !== null && typeof decoded.sub === 'string') {
        appleUserId = decoded.sub;
      } else {
        throw new Error('Invalid token payload structure or missing/invalid sub claim.');
      }
      console.log(`${routeName}: Verified session token for Apple User ID (sub): ${appleUserId}`);
    } catch (err: unknown) {
      console.error(`${routeName}: Session Token Verification Error:`, err instanceof Error ? err.message : 'Unknown error');
      let errorMessage = 'Unauthorized: Invalid session token.';
      if (err instanceof Error && err.name === 'TokenExpiredError') {
        errorMessage = 'Unauthorized: Session has expired.';
      }
      return NextResponse.json({ error: errorMessage }, { status: 401 });
    }

    // 3. Parse Request Body for Product ID
    let productId: string;
    try {
      const body = await req.json();
      if (!body || typeof body.productId !== 'string') {
        return NextResponse.json({ error: 'Invalid request body. Missing or invalid productId.' }, { status: 400 });
      }
      productId = body.productId;
    } catch (parseError) {
      console.error(`${routeName}: Error parsing request body:`, parseError);
      return NextResponse.json({ error: 'Invalid JSON in request body.' }, { status: 400 });
    }

    // 4. Validate Product ID and Get Credits to Add
    const creditsToAdd = iapProductCreditsMap[productId];
    if (creditsToAdd === undefined) {
      console.warn(`${routeName}: Invalid or unknown product ID received: ${productId} for user ${appleUserId}`);
      return NextResponse.json({ error: 'Invalid product ID.' }, { status: 400 });
    }
    console.log(`${routeName}: Valid product ID ${productId} received, attempting to add ${creditsToAdd} credits for user ${appleUserId}.`);

    // 5. Initialize Supabase Client
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });

    // 6. Increment User Credits
    // First, fetch the current credits to ensure the user exists and for returning the new total.
    const { data: userData, error: fetchError } = await supabase
      .from('users')
      .select('usage_credits')
      .eq('apple_user_id', appleUserId)
      .single();

    if (fetchError || !userData) {
      console.error(`${routeName}: Failed to fetch user ${appleUserId} or user not found:`, fetchError);
      return NextResponse.json({ error: 'User not found or database error.' }, { status: fetchError ? 500 : 404 });
    }

    const newCreditTotal = (userData.usage_credits || 0) + creditsToAdd;
    const { error: updateError } = await supabase
      .from('users')
      .update({ usage_credits: newCreditTotal })
      .eq('apple_user_id', appleUserId);

    if (updateError) {
      console.error(`${routeName}: Failed to update credits for user ${appleUserId}:`, updateError);
      return NextResponse.json({ error: 'Failed to update user credits.' }, { status: 500 });
    }

    console.log(`${routeName}: Successfully added ${creditsToAdd} credits to user ${appleUserId}. New total: ${newCreditTotal}`);
    const userInfo: UserInfo = {
      appleUserId: appleUserId,
      credits: newCreditTotal
    };
    return NextResponse.json({
      message: 'Credits added successfully.',
      userInfo: userInfo
    }, { status: 200 });
  } catch (err: unknown) {
    console.error(`${routeName}: Unhandled error in POST handler:`, err instanceof Error ? err.message : 'Unknown error');
    return NextResponse.json({ error: 'An unexpected internal server error occurred.' }, { status: 500 });
  }
} 