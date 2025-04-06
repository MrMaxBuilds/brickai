import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { NextRequest, NextResponse } from 'next/server';
import { v4 as uuidv4 } from 'uuid'; // Import uuid for unique filenames

// Helper function to get a file extension from MIME type
function getExtensionFromContentType(contentType: string | null): string {
  if (!contentType) return 'bin'; // Default extension if no content type
  // Basic mapping (add more as needed)
  switch (contentType.toLowerCase()) {
    case 'image/jpeg':
    case 'image/jpg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/gif':
      return 'gif';
    case 'image/webp':
      return 'webp';
    case 'image/svg+xml':
        return 'svg';
    // Add other types your app supports
    default:
      // Attempt to get the subtype after '/'
      const subtype = contentType.split('/')[1];
      return subtype ? subtype.split('+')[0] : 'bin'; // Handle things like svg+xml
  }
}


export async function POST(req: NextRequest) {
  try {
    // --- MODIFICATION START ---
    // 1. Get Content-Type header
    const contentType = req.headers.get('content-type');
    if (!contentType || !contentType.startsWith('image/')) {
      return NextResponse.json({ error: 'Invalid Content-Type. Must be an image type.' }, { status: 400 });
    }

    // 2. Read the raw request body as ArrayBuffer
    const buffer = await req.arrayBuffer();

    // 3. Check if body is empty
    if (!buffer || buffer.byteLength === 0) {
      return NextResponse.json({ error: 'No image data received in request body' }, { status: 400 });
    }
    
    // Convert ArrayBuffer to Node.js Buffer for S3 SDK v3
    const body = Buffer.from(buffer);
    // --- MODIFICATION END ---


    // Initialize the S3 client (same as before)
    const s3Client = new S3Client({
      region: process.env.AWS_REGION as string,
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID as string,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY as string,
      },
    });

    // Generate a unique key using UUID and derive extension from Content-Type
    const fileExtension = getExtensionFromContentType(contentType);
    const key = `images/${uuidv4()}.${fileExtension}`; // Use UUID for uniqueness

    // Prepare the upload parameters
    const uploadParams = {
      Bucket: process.env.AWS_S3_BUCKET_NAME as string,
      Key: key,
      Body: body, // Use the direct buffer
      ContentType: contentType, // Use the Content-Type from the request header
    };

    // Upload the file to S3 (same as before)
    await s3Client.send(new PutObjectCommand(uploadParams));

    // Construct the public URL (same as before)
    const url = `https://${process.env.AWS_S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

    // Return success response (same as before)
    return NextResponse.json({
      message: 'Image uploaded successfully',
      url,
    });
  } catch (err) {
    console.error('Error processing upload:', err); // Log the actual error
    // Provide a more generic error message to the client
    return NextResponse.json({ error: 'Error processing upload on the server.' }, { status: 500 });
  }
}