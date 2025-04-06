// File: web/src/app/api/upload/route.ts
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { NextRequest, NextResponse } from 'next/server';
import { v4 as uuidv4 } from 'uuid';
import jwt from 'jsonwebtoken'; // Use jsonwebtoken for backend token verification now

// Helper function to get a file extension from MIME type (keep as is)
function getExtensionFromContentType(contentType: string | null): string {
  if (!contentType) return 'bin';
  switch (contentType.toLowerCase()) {
    case 'image/jpeg': return 'jpg';
    case 'image/png': return 'png';
    case 'image/gif': return 'gif';
    case 'image/webp': return 'webp';
    case 'image/svg+xml': return 'svg';
    default:
      const subtype = contentType.split('/')[1];
      return subtype ? subtype.split('+')[0] : 'bin';
  }
}

// --- Main POST Handler ---
export async function POST(req: NextRequest) {
  let appleUserId: string | null = null; // Variable to store verified user ID from *our* token
  const backendJwtSecret = process.env.BACKEND_JWT_SECRET as string;

  try {
    // --- 1. Verify Backend Session Token ---
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized: Missing or invalid Authorization header.' }, { status: 401 });
    }
    const sessionToken = authHeader.substring(7); // Get the backend's session token

    try {
        // Verify the token using the backend's secret
        const decoded = jwt.verify(sessionToken, backendJwtSecret, {
            algorithms: ['HS256'], // Use the algorithm you used for signing
            issuer: 'BrickAIBackend', // Check issuer matches what you set
            // Add audience check if you set one
        }) as jwt.JwtPayload; // Type assertion

        if (!decoded || typeof decoded.sub !== 'string') {
          throw new Error('Invalid token payload or missing sub claim.');
        }
        appleUserId = decoded.sub; // Extract the Apple User ID from *our* token's 'sub' claim
        console.log(`Verified session token for Apple User ID (sub): ${appleUserId}`);

    } catch (err: any) {
        console.error('Backend Session Token Verification Error:', err.message);
        let errorMessage = 'Unauthorized: Invalid session token.';
        if (err.name === 'TokenExpiredError') {
            errorMessage = 'Unauthorized: Session has expired.';
        } else if (err.name === 'JsonWebTokenError') {
             errorMessage = 'Unauthorized: Malformed session token.';
        }
        // You could potentially trigger refresh logic here if applicable,
        // but typically the client handles expired session tokens by re-authenticating or refreshing.
        return NextResponse.json({ error: errorMessage }, { status: 401 });
    }
    // --- End Token Verification ---


    // --- 2. Process Image Upload (mostly the same as before) ---
    const contentType = req.headers.get('content-type');
    if (!contentType || !contentType.startsWith('image/')) {
      return NextResponse.json({ error: 'Invalid Content-Type. Must be an image type.' }, { status: 400 });
    }
    const buffer = await req.arrayBuffer();
    if (!buffer || buffer.byteLength === 0) {
      return NextResponse.json({ error: 'No image data received in request body' }, { status: 400 });
    }
    const body = Buffer.from(buffer);

    const s3Client = new S3Client({
        region: process.env.AWS_REGION as string,
        credentials: { accessKeyId: process.env.AWS_ACCESS_KEY_ID as string, secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY as string },
    });

    const fileExtension = getExtensionFromContentType(contentType);
    // Use the appleUserId obtained from the verified *session token*
    const key = `images/${appleUserId}/${uuidv4()}.${fileExtension}`;

    const uploadParams = {
      Bucket: process.env.AWS_S3_BUCKET_NAME as string,
      Key: key,
      Body: body,
      ContentType: contentType,
    };

    await s3Client.send(new PutObjectCommand(uploadParams));

    const url = `https://${process.env.AWS_S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

    // Return success response
    return NextResponse.json({
      message: 'Image uploaded successfully',
      url,
      // No longer need to return appleUserId, client already knows or doesn't care here
    });

  } catch (err: any) {
    console.error('Unhandled Error in Upload Route:', err);
    return NextResponse.json({ error: 'Internal server error during upload processing.' }, { status: 500 });
  }
}