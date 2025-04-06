import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  try {
    // Parse the form data from the request
    const formData = await req.formData();
    
    // Get the file from the 'image' field
    const file = formData.get('image');
    
    // Validate the file exists and is a File object
    if (!file || !(file instanceof File)) {
      return NextResponse.json({ error: 'No image uploaded' }, { status: 400 });
    }

    // Convert the file stream to a buffer
    const buffer = await file.arrayBuffer();
    const body = Buffer.from(buffer);

    // Initialize the S3 client
    const s3Client = new S3Client({
      region: process.env.AWS_REGION as string,
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID as string,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY as string,
      },
    });

    // Generate a unique key for the S3 object
    const key = `images/${Date.now()}_${file.name}`;

    // Prepare the upload parameters
    const uploadParams = {
      Bucket: process.env.AWS_S3_BUCKET_NAME as string,
      Key: key,
      Body: body,
      ContentType: file.type,
    };

    // Upload the file to S3
    await s3Client.send(new PutObjectCommand(uploadParams));

    // Construct the public URL
    const url = `https://${process.env.AWS_S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

    // Return success response
    return NextResponse.json({
      message: 'Image uploaded successfully',
      url,
    });
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: 'Error processing upload' }, { status: 500 });
  }
}