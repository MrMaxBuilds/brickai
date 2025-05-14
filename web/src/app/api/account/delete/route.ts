import { NextRequest, NextResponse } from 'next/server';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';

const requiredEnvVars = [
  'BACKEND_JWT_SECRET',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];

// Helper function to check environment variables
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

export async function DELETE(req: NextRequest) {
  const routeName = 'Account Delete Route';

  // 1. Environment Variable Check
  const envCheck = checkEnvVars(requiredEnvVars, routeName);
  if (!envCheck.valid) {
    return NextResponse.json({ error: `Internal Server Configuration Error: Missing env var: ${envCheck.missing}` }, { status: 500 });
  }

  const backendJwtSecret = process.env.BACKEND_JWT_SECRET!;
  const supabaseUrl = process.env.SUPABASE_URL!;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  let appleUserIdFromToken: string;

  try {
    // 2. Verify Backend Session Token (Credentials Validation)
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized: Missing or invalid Authorization header.' }, { status: 401 });
    }
    const sessionToken = authHeader.substring(7);

    try {
      const decoded = jwt.verify(sessionToken, backendJwtSecret, { algorithms: ['HS256'], issuer: 'BrickAIBackend' });
      if (typeof decoded === 'object' && decoded !== null && typeof decoded.sub === 'string') {
        appleUserIdFromToken = decoded.sub; // This is the "appleUserID as input"
      } else {
        throw new Error('Invalid token payload structure or missing/invalid sub claim.');
      }
      console.log(`${routeName}: Verified session token for Apple User ID (sub): ${appleUserIdFromToken}`);
    } catch (err: unknown) {
      console.error(`${routeName}: Session Token Verification Error:`, err instanceof Error ? err.message : 'Unknown error');
      let errorMessage = 'Unauthorized: Invalid session token.';
      if (err instanceof Error && err.name === 'TokenExpiredError') {
        errorMessage = 'Unauthorized: Session has expired.';
      }
      return NextResponse.json({ error: errorMessage }, { status: 401 });
    }

    // 3. Initialize Supabase Client
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });

    // 4. Delete User from Database
    console.log(`${routeName}: Attempting to delete user account for Apple User ID: ${appleUserIdFromToken}`);
    const { error: deleteError, count } = await supabase
      .from('users')
      .delete()
      .eq('apple_user_id', appleUserIdFromToken);

    if (deleteError) {
      console.error(`${routeName}: Supabase delete error for Apple User ID ${appleUserIdFromToken}:`, deleteError);
      return NextResponse.json({ error: 'Failed to delete account due to a database error.' }, { status: 500 });
    }

    console.log(`${routeName}: Deletion complete for Apple User ID ${appleUserIdFromToken}. Rows affected: ${count ?? 0}`); // Handle null count

    // If count is 0, the user was not found, which is fine (idempotent).
    // If count is 1 (or more, though apple_user_id is unique), user was deleted.
    return NextResponse.json({ message: 'Account deleted successfully.' }, { status: 200 });

  } catch (err: unknown) {
    // Catch any other unexpected errors
    console.error(`${routeName}: Unhandled error in DELETE handler:`, err instanceof Error ? err.message : 'Unknown error');
    return NextResponse.json({ error: 'An unexpected internal server error occurred.' }, { status: 500 });
  }
} 