import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { NextRequest, NextResponse } from 'next/server';
import { v4 as uuidv4 } from 'uuid';
import jwt, { JwtHeader, SigningKeyCallback } from 'jsonwebtoken'; // Use jsonwebtoken
import jwksClient from 'jwks-rsa'; // To fetch Apple's public keys

// --- Environment Variable Check ---
const requiredEnvVars = [
  'AWS_REGION',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_S3_BUCKET_NAME',
  'APPLE_BUNDLE_ID', // Added
];

for (const varName of requiredEnvVars) {
  if (!process.env[varName]) {
    console.error(`Missing required environment variable: ${varName}`);
  }
}
// --- End Environment Variable Check ---


// --- Apple Public Key Retrieval ---
const appleClient = jwksClient({
  jwksUri: 'https://appleid.apple.com/auth/keys', // Apple's JWKS endpoint
  cache: true, // Enable caching
  cacheMaxEntries: 5, // Cache up to 5 keys
  cacheMaxAge: 60 * 60 * 1000, // Cache for 1 hour (in milliseconds)
});

function getAppleSigningKey(header: JwtHeader, callback: SigningKeyCallback): void {
  if (!header.kid) {
    return callback(new Error('No kid found in JWT header'));
  }
  appleClient.getSigningKey(header.kid, (err, key) => {
    if (err) {
      return callback(err);
    }
    const signingKey = key?.getPublicKey(); // Handles both Cert and RSA keys
    callback(null, signingKey);
  });
}
// --- End Apple Public Key Retrieval ---


// Helper function to get a file extension from MIME type (same as before)
function getExtensionFromContentType(contentType: string | null): string {
    // ... (keep the function from the previous version) ...
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
  let appleUserId: string = "nouser"; // Variable to store verified user ID

  try {
    // --- 1. Verify Apple Identity Token ---
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized: Missing or invalid Authorization header.' }, { status: 401 });
    }
    const identityToken = authHeader.substring(7); // Remove 'Bearer ' prefix

    if (process.env.NODE_ENV === 'production') {
      try {
          // Promisify jwt.verify with the key lookup function
        const decoded = await new Promise<jwt.JwtPayload | undefined>((resolve, reject) => {
            jwt.verify(
              identityToken,
              getAppleSigningKey, // Function to fetch the public key based on kid
              {
                algorithms: ['RS256'], // Apple uses RS256
                issuer: 'https://appleid.apple.com', // Check the issuer
                audience: process.env.APPLE_BUNDLE_ID, // Check the audience (your app's bundle ID)
              },
              (err, decodedPayload) => {
                if (err) {
                  return reject(err);
                }
                resolve(decodedPayload as jwt.JwtPayload | undefined);
              }
            );
        });

        if (!decoded || typeof decoded.sub !== 'string') {
          throw new Error('Invalid token payload or missing sub claim.');
        }
        appleUserId = decoded.sub; // Store the verified Apple User ID
        console.log(`Verified Apple User ID (sub): ${appleUserId}`);

      } catch (err: any) {
        console.error('Apple Token Verification Error:', err.message);
        // Handle specific JWT errors if needed (e.g., TokenExpiredError, JsonWebTokenError)
        let errorMessage = 'Unauthorized: Invalid token.';
        if (err.name === 'TokenExpiredError') {
            errorMessage = 'Unauthorized: Token has expired.';
        }
        return NextResponse.json({ error: errorMessage }, { status: 401 });
      }
    }
    // --- End Token Verification ---


    // --- 2. Process Image Upload (similar to before) ---
    const contentType = req.headers.get('content-type');
    if (!contentType || !contentType.startsWith('image/')) {
      return NextResponse.json({ error: 'Invalid Content-Type. Must be an image type.' }, { status: 400 });
    }
    const buffer = await req.arrayBuffer();
    if (!buffer || buffer.byteLength === 0) {
      return NextResponse.json({ error: 'No image data received in request body' }, { status: 400 });
    }
    const body = Buffer.from(buffer);

    const s3Client = new S3Client({ /* ... S3 config ... */
        region: process.env.AWS_REGION as string,
        credentials: { accessKeyId: process.env.AWS_ACCESS_KEY_ID as string, secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY as string },
    });

    const fileExtension = getExtensionFromContentType(contentType);
    // Add user identifier to the key path for organization (optional but recommended)
    const key = `images/${appleUserId}/${uuidv4()}.${fileExtension}`;

    const uploadParams = {
      Bucket: process.env.AWS_S3_BUCKET_NAME as string,
      Key: key,
      Body: body,
      ContentType: contentType,
       // --- Add Apple User ID as Metadata ---
      // Metadata: {
      //   'apple-user-id': appleUserId, // Store verified user ID
      // },
      // ------------------------------------
    };

    await s3Client.send(new PutObjectCommand(uploadParams));

    const url = `https://${process.env.AWS_S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

    // Return success response, maybe include the user ID for confirmation
    return NextResponse.json({
      message: 'Image uploaded successfully',
      url,
      appleUserId: appleUserId // Optionally return the user ID
    });

  } catch (err: any) { // Catch all other errors
    console.error('Unhandled Error in Upload Route:', err);
    return NextResponse.json({ error: 'Internal server error during upload processing.' }, { status: 500 });
  }
}