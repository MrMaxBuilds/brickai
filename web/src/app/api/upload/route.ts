// File: web/src/app/api/upload/route.ts
// Modified to save image metadata to Supabase after S3 upload

import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { NextRequest, NextResponse } from 'next/server';
import { v4 as uuidv4 } from 'uuid';
import jwt from 'jsonwebtoken'; // Removed unused JwtPayload import
import { createClient } from '@supabase/supabase-js'; // Supabase client

// --- Environment Variable Check ---
// Add Supabase & ensure S3/JWT vars are present
const requiredEnvVars = [
  'AWS_REGION',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_S3_BUCKET_NAME',
  'BACKEND_JWT_SECRET',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY'
];

function checkEnvVars(): { valid: boolean, missing?: string } {
    for (const varName of requiredEnvVars) {
        if (!process.env[varName]) {
            console.error(`Upload Route: Missing required environment variable: ${varName}`);
            return { valid: false, missing: varName };
        }
    }
    return { valid: true };
}
// --- End Environment Variable Check ---


// Helper function to get a file extension (remains the same)
function getExtensionFromContentType(contentType: string | null): string {
  if (!contentType) return 'bin';
  // Keep jpg as default? Or make bin default? Let's keep jpg for images.
  const defaultExt = 'jpg'; // Changed from let to const
  switch (contentType.toLowerCase()) {
    case 'image/jpeg': return 'jpg';
    case 'image/png': return 'png';
    case 'image/gif': return 'gif';
    case 'image/webp': return 'webp';
    case 'image/svg+xml': return 'svg';
    default:
      const subtype = contentType.split('/')[1];
      return subtype ? subtype.split('+')[0] : defaultExt;
  }
}

// Helper to construct S3 URL
function getS3Url(bucket: string, region: string, key: string): string {
    return `https://${bucket}.s3.${region}.amazonaws.com/${key}`;
}

// --- Main POST Handler ---
export async function POST(req: NextRequest) {
  let appleUserId: string; // Initialize after verification

  // --- Check Environment Variables ---
  const envCheck = checkEnvVars();
  if (!envCheck.valid) {
    return NextResponse.json({ error: `Internal Server Configuration Error: Missing env var: ${envCheck.missing}` }, { status: 500 });
  }
  const backendJwtSecret = process.env.BACKEND_JWT_SECRET as string;
  const supabaseUrl = process.env.SUPABASE_URL as string;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string;
  const awsRegion = process.env.AWS_REGION as string;
  const awsAccessKeyId = process.env.AWS_ACCESS_KEY_ID as string;
  const awsSecretAccessKey = process.env.AWS_SECRET_ACCESS_KEY as string;
  const awsS3BucketName = process.env.AWS_S3_BUCKET_NAME as string;

  try {
    // --- 1. Verify Backend Session Token ---
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized: Missing or invalid Authorization header.' }, { status: 401 });
    }
    const sessionToken = authHeader.substring(7);

    try {
        const decoded = jwt.verify(sessionToken, backendJwtSecret, {
            algorithms: ['HS256'], issuer: 'BrickAIBackend'
        });
        // Type check for 'sub'
        if (typeof decoded === 'object' && decoded !== null && typeof decoded.sub === 'string') {
            appleUserId = decoded.sub;
        } else {
            throw new Error('Invalid token payload structure or missing/invalid sub claim.');
        }
        console.log(`Upload Route: Verified session token for Apple User ID (sub): ${appleUserId}`);

    } catch (err: unknown) {
        console.error('Upload Route: Backend Session Token Verification Error:', 
          err instanceof Error ? err.message : 'Unknown error');
        let errorMessage = 'Unauthorized: Invalid session token.';
        if (err instanceof Error && err.name === 'TokenExpiredError') { 
          errorMessage = 'Unauthorized: Session has expired.'; 
        }
        // NOTE: This route doesn't automatically trigger refresh. Client needs to handle 401.
        return NextResponse.json({ error: errorMessage }, { status: 401 });
    }
    // --- End Token Verification ---


    // --- 2. Process Image Upload ---
    const contentType = req.headers.get('content-type');
    if (!contentType || !contentType.startsWith('image/')) {
      return NextResponse.json({ error: 'Invalid Content-Type. Must be an image type.' }, { status: 400 });
    }
    const buffer = await req.arrayBuffer();
    if (!buffer || buffer.byteLength === 0) {
      return NextResponse.json({ error: 'No image data received in request body' }, { status: 400 });
    }
    const body = Buffer.from(buffer);

    // --- 3. Upload to S3 ---
    const s3Client = new S3Client({
        region: awsRegion,
        credentials: { accessKeyId: awsAccessKeyId, secretAccessKey: awsSecretAccessKey },
    });

    const fileExtension = getExtensionFromContentType(contentType);
    // S3 Key includes user ID for organization
    const s3Key = `images/${appleUserId}/${uuidv4()}.${fileExtension}`;

    const uploadParams = { Bucket: awsS3BucketName, Key: s3Key, Body: body, ContentType: contentType };
    console.log(`Upload Route: Uploading to S3 key: ${s3Key}`);
    await s3Client.send(new PutObjectCommand(uploadParams));
    console.log(`Upload Route: Successfully uploaded to S3.`);

    // --- 4. Save Metadata to Supabase ---
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
        auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });

    console.log(`Upload Route: Saving image metadata to Supabase for user ${appleUserId}`);
    const { error: dbError } = await supabase
        .from('images') // Ensure 'images' matches your table name
        .insert({
            apple_user_id: appleUserId,
            original_s3_key: s3Key,
            status: 'UPLOADED'
            // prompt will be null by default if column allows null
        });

    if (dbError) {
        // Log the DB error but potentially proceed? Or return failure?
        // If DB write fails, the S3 upload is orphaned. Best to return an error.
        console.error('Upload Route: Supabase insert error:', dbError);
        // Consider cleanup of S3 object? Complex. Let's return error for now.
        return NextResponse.json({ error: `Failed to save image metadata: ${dbError.message}` }, { status: 500 });
    }
    console.log(`Upload Route: Successfully saved metadata to Supabase.`);

    // --- 5. Construct Response ---
    const originalImageUrl = getS3Url(awsS3BucketName, awsRegion, s3Key);

    // Return success response with the URL of the *original* uploaded image
    return NextResponse.json({
      message: 'Image uploaded and metadata saved successfully',
      url: originalImageUrl // Send back the URL as before
    });

  } catch (err: unknown) {
    console.error('Upload Route: Unhandled Error:', 
      err instanceof Error ? err.message : 'Unknown error');
    return NextResponse.json({ error: 'Internal server error during upload processing.' }, { status: 500 });
  }
}