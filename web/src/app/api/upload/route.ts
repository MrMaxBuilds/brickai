// File: web/src/app/api/upload/route.ts
// Modified to save image metadata, trigger processing via external API,
// log the streaming response thoroughly, mark status as FAILED pending analysis,
// and use shared utility functions.

import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { NextRequest, NextResponse } from 'next/server';
import { v4 as uuidv4 } from 'uuid';
import jwt from 'jsonwebtoken';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { getUserCredits, modifyCredits } from '@/user/utils';
import fs from 'fs';
import path from 'path';

// --- Environment Variable List ---
const requiredEnvVars = [
  'AWS_REGION',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_S3_BUCKET_NAME',
  'BACKEND_JWT_SECRET',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'PIAPI_API_KEY',
];

// --- Helper Function: Process Image Stream, Accumulate, and Update DB ---
async function processImageAndLogStream(
    supabase: SupabaseClient,
    s3Client: S3Client,
    imageId: number | string,
    originalImageUrl: string,
    appleUserId: string,
    awsS3BucketName: string,
    awsRegion: string,
    piApiKey: string
): Promise<boolean> {
    const processingApiUrl = 'https://api.piapi.ai/v1/chat/completions';
    // Use lots of detailed colors and try to keep their features intact. 
    const defaultPromptPath = path.resolve('./src/app/api/upload/defaultPrompt.txt');
    const defaultPrompt = fs.readFileSync(defaultPromptPath, 'utf-8');
    let success = false;
    let fullContentString = ''; // Accumulator for the content fragments
    let processingError: Error | null = null; // Store error during processing
    let failureReason = "Unknown processing error"; // Default reason

    console.log(`Upload Route: Starting image processing & stream logging for DB image ID: ${imageId}, URL: ${originalImageUrl}`);

    try {
        // 1. Update status to PROCESSING
        await supabase
            .from('images')
            .update({ status: 'PROCESSING', updated_at: new Date().toISOString() })
            .eq('id', imageId);

        // 2. Call the external processing API with stream: true
        console.log(`Upload Route: Calling external API (stream=true) for image ID ${imageId}...`);
        const apiResponse = await fetch(processingApiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${piApiKey}`,
                'Accept': 'text/event-stream', // Expect SSE
            },
            body: JSON.stringify({
                model: "gpt-4o-image", // Or appropriate model
                messages: [
                    {
                        role: "user",
                        content: [
                            { type: "image_url", image_url: { url: originalImageUrl } },
                            { type: "text", text: defaultPrompt } // Use actual prompt if available
                        ]
                    }
                ],
                stream: true, // Ensure streaming is enabled
            }),
        });

        if (!apiResponse.ok) {
            const errorBody = await apiResponse.text();
            console.error(`Upload Route: External API HTTP Error (${apiResponse.status}) for image ID ${imageId}: ${errorBody}`);
            throw new Error(`External API failed with status ${apiResponse.status}`);
        }
        if (!apiResponse.body) {
             console.error(`Upload Route: External API response body is null for image ID ${imageId}.`);
            throw new Error("External API returned no response body");
        }

        // 3. Process the stream, log, and accumulate content
        console.log(`Upload Route: Processing stream response for image ID ${imageId}...`);
        const reader = apiResponse.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        let done = false;
        let messageCount = 0;

        while (!done) {
            const { value, done: readerDone } = await reader.read();
            done = readerDone;

            if (value) {
                const chunk = decoder.decode(value, { stream: true });
                // console.log(`\n--- RAW CHUNK (Image ID: ${imageId}) ---\n${chunk}\n--- END RAW CHUNK ---`); // Optional: Very verbose
                buffer += chunk;

                let boundary = buffer.indexOf('\n');
                while (boundary !== -1) {
                    const line = buffer.substring(0, boundary).trim();
                    buffer = buffer.substring(boundary + 1);

                    if (line.startsWith('data:')) {
                        messageCount++;
                        const jsonData = line.substring(5).trim();

                        if (jsonData === '[DONE]') {
                            console.log(`--- SSE [DONE] signal received (Image ID: ${imageId}) ---`);
                            done = true; // Treat [DONE] signal also as stream end for our loop logic
                            break;
                        }

                        try {
                            const parsedData = JSON.parse(jsonData);

                            // Accumulate content fragments
                            const contentFragment = parsedData?.choices?.[0]?.delta?.content;
                            if (typeof contentFragment === 'string') {
                                fullContentString += contentFragment;
                                console.log(`--- Accumulated Content (Image ID: ${imageId}): ${fullContentString} ---`); // Optional: log growth
                            }

                        } catch (parseError) {
                             console.error(`--- JSON Parse Error on line ${messageCount} (Image ID: ${imageId}) ---`);
                             console.error(`   Error: ${parseError instanceof Error ? parseError.message : parseError}`);
                             console.error(`   Data: ${jsonData}`);
                             console.error(`--- End Parse Error ---`);
                        }
                    } else if (line) {
                         console.log(`\n--- Non-SSE Line Received (Image ID: ${imageId}) ---\n${line}\n---`);
                    }
                    boundary = buffer.indexOf('\n');
                }
            }
        } // end while !done reader loop

        // Process any remaining buffer content (e.g., last line without newline)
        // This part might be less critical if [DONE] is reliably sent, but good practice
        if (buffer.trim()) {
             console.log(`\n--- Processing Remaining Buffer (Image ID: ${imageId}) ---\n${buffer.trim()}\n---`);
            buffer.split('\n').forEach(line => {
                 line = line.trim();
                 if (line.startsWith('data:')) { /* ... similar parsing logic as above if needed ... */ }
            });
        }

        console.log(`Upload Route: Finished processing stream response for image ID ${imageId}.`);
        console.log(`Upload Route: Final Accumulated Content String (Image ID: ${imageId}):\n${fullContentString}`);

        // --- 4. Attempt to Process Accumulated Content ---
        const markdownUrlRegex = /!\[.*?\]\((.*?)\)/; // Capture group 1 is the URL
        const match = fullContentString.match(markdownUrlRegex);
        const processedImageUrl = match?.[1]; // Get the first capture group

        if (!processedImageUrl) {
            console.error(`Upload Route: Could not extract image URL from Markdown in accumulated content for image ID ${imageId}.`);
            failureReason = "Could not find image URL in final API response content.";
            throw new Error(failureReason); // Throw error to trigger FAILED status in finally block
        }

        console.log(`Upload Route: Extracted processed image URL for image ID ${imageId}: ${processedImageUrl}`);

        // 5. Download the processed image data
        console.log(`Upload Route: Downloading processed image from URL for image ID ${imageId}...`);
        const imageResponse = await fetch(processedImageUrl);
        if (!imageResponse.ok) {
            failureReason = `Failed to download processed image from ${processedImageUrl}, status: ${imageResponse.status}`;
            throw new Error(failureReason);
        }
        if (!imageResponse.body) {
             failureReason = `Processed image download response body is null from ${processedImageUrl}`;
             throw new Error(failureReason);
        }
        const processedImageBuffer = await imageResponse.arrayBuffer();
        const processedContentType = imageResponse.headers.get('content-type');
        const processedFileExtension = getExtensionFromContentType(processedContentType);
        console.log(`Upload Route: Downloaded processed image for image ID ${imageId}. Content-Type: ${processedContentType}, Size: ${processedImageBuffer.byteLength}`);

        // 6. Upload processed image to OUR S3
        const processedS3Key = `processed-images/${appleUserId}/${uuidv4()}.${processedFileExtension}`;
        const uploadParams = {
            Bucket: awsS3BucketName,
            Key: processedS3Key,
            Body: Buffer.from(processedImageBuffer),
            ContentType: processedContentType || 'application/octet-stream',
        };
        console.log(`Upload Route: Uploading processed image to S3 key for image ID ${imageId}: ${processedS3Key}`);
        await s3Client.send(new PutObjectCommand(uploadParams));
        console.log(`Upload Route: Successfully uploaded processed image to S3 for image ID ${imageId}.`);

        // 7. Update DB record to COMPLETED
        const { error: updateError } = await supabase
            .from('images')
            .update({
                processed_s3_key: processedS3Key,
                status: 'COMPLETED',
                prompt: defaultPrompt, // Optionally save the used prompt
                updated_at: new Date().toISOString()
            })
            .eq('id', imageId);

        if (updateError) {
            console.error(`Upload Route: Failed to update DB status to COMPLETED for image ID ${imageId}:`, updateError);
            failureReason = `Failed final DB update: ${updateError.message}`;
            success = false; // Mark as not fully successful
            console.error(`Upload Route: DB update failed but processed image ${processedS3Key} was uploaded to S3.`);
             // No throw here, let finally block handle FAILED status based on success flag
        } else {
             console.log(`Upload Route: Successfully marked image ID ${imageId} as COMPLETED in DB.`);
             success = true; // Mark as fully successful
        }

    } catch (error: unknown) {
        console.error(`Upload Route: Error during stream processing or subsequent steps for image ID ${imageId}:`, error instanceof Error ? error.message : error);
        processingError = error instanceof Error ? error : new Error(String(error));
        // Use specific reason if set, otherwise use error message
        failureReason = (failureReason === "Unknown processing error" && processingError) ? processingError.message : failureReason;
        success = false; // Ensure success is false if any error is caught
    } finally {
        // Update status to FAILED only if the process didn't fully complete successfully
        if (!success) {
            try {
                await supabase
                    .from('images')
                    .update({
                         status: 'FAILED',
                         // failure_reason: failureReason.substring(0, 255), // If column exists
                         updated_at: new Date().toISOString()
                        })
                    .eq('id', imageId);
                 console.log(`Upload Route: Marked image ID ${imageId} as FAILED in DB. Reason: ${failureReason}`);
            } catch (dbUpdateError) {
                console.error(`Upload Route: CRITICAL - Failed to update status to FAILED for image ID ${imageId} after processing error:`, dbUpdateError);
            }
        }
    }
    return success; // MODIFIED: Return success status
}
// --- End Helper Function ---


// --- Main POST Handler ---
export async function POST(req: NextRequest) {
    const routeName = "Upload Route";
    let appleUserId: string = "unknown_user";
    let imageId: number | string | null = null;
    let originalImageUrl: string | null = null;
    let initialCredits = -1;
    let creditsDecremented = false;

    // --- Use Imported Environment Variable Check ---
    const envCheck = checkEnvVars(requiredEnvVars, routeName);
    if (!envCheck.valid) {
        return NextResponse.json({ error: `Internal Server Configuration Error: Missing env var: ${envCheck.missing}`, userInfo: { appleUserId, credits: -1 } }, { status: 500 });
    }
    // Retrieve validated environment variables
    const backendJwtSecret = process.env.BACKEND_JWT_SECRET!;
    const supabaseUrl = process.env.SUPABASE_URL!;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
    const awsRegion = process.env.AWS_REGION!;
    const awsAccessKeyId = process.env.AWS_ACCESS_KEY_ID!;
    const awsSecretAccessKey = process.env.AWS_SECRET_ACCESS_KEY!;
    const awsS3BucketName = process.env.AWS_S3_BUCKET_NAME!;
    const piApiKey = process.env.PIAPI_API_KEY!;

    // Initialize S3 Client
    const s3Client = new S3Client({
        region: awsRegion,
        credentials: { accessKeyId: awsAccessKeyId, secretAccessKey: awsSecretAccessKey },
    });
    // Initialize Supabase Client
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
        auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });

    try {
        // --- 1. Verify Backend Session Token ---
        const authHeader = req.headers.get('authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return NextResponse.json({ error: 'Unauthorized: Missing or invalid Authorization header.', userInfo: { appleUserId: "unknown_user", credits: -1 } }, { status: 401 });
        }
        const sessionToken = authHeader.substring(7);
        try {
            const decoded = jwt.verify(sessionToken, backendJwtSecret, { algorithms: ['HS256'], issuer: 'BrickAIBackend' }) as jwt.JwtPayload;
            if (decoded && typeof decoded.sub === 'string') { 
                appleUserId = decoded.sub;
            } else { 
                throw new Error('Invalid token payload.'); 
            }
        } catch {
            return NextResponse.json({ error: 'Unauthorized: Invalid session token.', userInfo: { appleUserId, credits: -1 } }, { status: 401 });
        }

        // --- 1.5. Check User Credits --- ADDED STEP
        console.log(`Upload Route: Checking credits for user ${appleUserId}`);
        const creditsCheck = await getUserCredits(supabase, appleUserId);
        if (creditsCheck.error || !creditsCheck.data) {
            const errorMsg = creditsCheck.error?.message || "User not found or error fetching credits.";
            const status = creditsCheck.error?.code === 'PGRST116' || !creditsCheck.data ? 404 : 500;
            return NextResponse.json({ error: errorMsg, userInfo: { appleUserId, credits: creditsCheck.data?.credits ?? 0} }, { status });
        }
        initialCredits = creditsCheck.data.credits;
        if (initialCredits <= 0) {
            console.log(`Upload Route: User ${appleUserId} has insufficient credits (${initialCredits}).`);
            return NextResponse.json({ error: 'Insufficient credits. Please purchase more.', userInfo: creditsCheck.data }, { status: 402 });
        }
        console.log(`Upload Route: User ${appleUserId} has ${initialCredits} credits. Proceeding.`);

        // --- 2. Attempt to decrement credits
        console.log(`${routeName}: User ${appleUserId} has ${initialCredits} credits. Attempting to decrement.`);
        const decrementResult = await modifyCredits(supabase, appleUserId, -1);
        if (decrementResult.error || !decrementResult.data) {
            console.error(`${routeName}: Failed to decrement credits for user ${appleUserId}:`, decrementResult.error);
            // Return error, user was not charged. Use initial credits for userInfo.
            return NextResponse.json({ error: 'Failed to process charge.', userInfo: { appleUserId, credits: initialCredits } }, { status: 500 });
        }
        creditsDecremented = true;
        const currentCreditsInResponse = decrementResult.data.credits;
        console.log(`${routeName}: Credits successfully decremented for user ${appleUserId}. New balance: ${currentCreditsInResponse}`);

        // --- 3. Process Image Upload (Get image data) ---
        const contentType = req.headers.get('content-type');
        if (!contentType || !contentType.startsWith('image/')) {
            throw new Error('Invalid Content-Type. Must be an image type.');
        }
        const buffer = await req.arrayBuffer();
        if (!buffer || buffer.byteLength === 0) {
            throw new Error('No image data received in request body');
        }
        const body = Buffer.from(buffer);

        // --- 4. Upload Original Image to S3 ---
        // (Code unchanged, uses utils)
        const fileExtension = getExtensionFromContentType(contentType);
        const s3Key = `images/${appleUserId}/${uuidv4()}.${fileExtension}`;
        const uploadParams = { Bucket: awsS3BucketName, Key: s3Key, Body: body, ContentType: contentType };
        console.log(`Upload Route: Uploading original image to S3 key: ${s3Key}`);
        await s3Client.send(new PutObjectCommand(uploadParams));
        console.log(`Upload Route: Successfully uploaded original image to S3.`);
        originalImageUrl = getS3Url(awsS3BucketName, awsRegion, s3Key);
        if (!originalImageUrl) {
             console.error('Upload Route: Failed to construct S3 URL after upload.');
             return NextResponse.json({ error: 'Failed to construct S3 URL after upload.' }, { status: 500 });
        }

        // --- 5. Save Initial Metadata to Supabase & Get ID ---
        // (Code unchanged)
        console.log(`Upload Route: Saving initial image metadata to Supabase for user ${appleUserId}`);
        const { data: insertedData, error: dbError } = await supabase.from('images').insert({ apple_user_id: appleUserId, original_s3_key: s3Key, status: 'UPLOADED' }).select('id').single();
        if (dbError) { console.error('Upload Route: Supabase insert error:', dbError); return NextResponse.json({ error: `Failed to save image metadata: ${dbError.message}` }, { status: 500 }); }
        if (!insertedData || !insertedData.id) { console.error('Upload Route: Supabase insert did not return the image ID.'); return NextResponse.json({ error: 'Failed to get image ID after saving metadata.' }, { status: 500 }); }
        imageId = insertedData.id;
        console.log(`Upload Route: Successfully saved metadata to Supabase. Image ID: ${imageId}`);

        // --- 6. Trigger Image Stream Processing and Update (Synchronous Call) ---
        console.log("Upload Route: Triggering synchronous image stream processing, accumulation, and update attempt...");
        const processingSuccessful = await processImageAndLogStream(
            supabase,
            s3Client,
            imageId || 0,
            originalImageUrl,
            appleUserId,
            awsS3BucketName,
            awsRegion,
            piApiKey
        );
         console.log(`Upload Route: Synchronous stream processing and update function finished. Success: ${processingSuccessful}`);

        if (!processingSuccessful) {
            throw new Error('Image processing failed after initial upload and charge.'); // Will be caught and credit refunded
        }
        
        // SUCCESS CASE: Credit was decremented, processing successful.
        console.log(`${routeName}: Successfully processed image ${imageId} for user ${appleUserId}. Final credits: ${currentCreditsInResponse}`);
        return NextResponse.json({
            message: 'Image upload accepted and processed successfully.',
            url: originalImageUrl, // Or processedImageUrl if preferred by client for immediate display
            userInfo: { appleUserId, credits: currentCreditsInResponse }
        }, { status: 200 });

    } catch (err: unknown) {
        const error = err instanceof Error ? err : new Error('Unknown error during upload processing');
        console.error(`${routeName}: Unhandled Error in POST handler:`, error.message);
        let finalCreditsForResponse = initialCredits; // Default to initial if decrement never happened or failed

        if (creditsDecremented) {
            console.warn(`${routeName}: Error occurred after credits were decremented for ${appleUserId}. Attempting to refund credit.`);
            const refundResult = await modifyCredits(supabase, appleUserId, 1);
            if (refundResult.error || !refundResult.data) {
                console.error(`${routeName}: CRITICAL - Failed to refund credit for user ${appleUserId} after error:`, refundResult.error);
                // In this critical failure, the user was charged but an error occurred. Respond with credits *before* attempted refund.
                // The `currentCreditsInResponse` would reflect the decremented state if decrement was successful.
                // If decrement wasn't successful, `initialCredits` is more accurate.
                // Let's assume if `creditsDecremented` is true, `decrementResult.data.credits` was set.
                finalCreditsForResponse = (await getUserCredits(supabase, appleUserId)).data?.credits ?? initialCredits; // Re-fetch for most accuracy
            } else {
                console.log(`${routeName}: Successfully refunded credit for user ${appleUserId}. New balance: ${refundResult.data.credits}`);
                finalCreditsForResponse = refundResult.data.credits;
            }
        } else {
            // If credits were never decremented, try to get the most current count if initial check failed
             const latestCredits = await getUserCredits(supabase, appleUserId);
             finalCreditsForResponse = latestCredits.data?.credits ?? initialCredits; // Use fetched if available, else initial
             if (latestCredits.error && appleUserId !== "unknown_user") { // Only warn if we expected to find a user
                 console.warn(`${routeName}: Could not re-fetch credits for error response userInfo for user ${appleUserId}. Using initial: ${initialCredits}`);
             }
        }
        
        // Mark image as FAILED if an ID was generated
        if (imageId && supabase) {
             try {
                await supabase.from('images').update({ status: 'FAILED', updated_at: new Date().toISOString() }).eq('id', imageId).maybeSingle();
             } catch (dbUpdateError) { console.error(`${routeName}: CRITICAL - Failed to mark image as FAILED in main catch block:`, dbUpdateError); }
        }

        // Determine appropriate status code for the error
        let statusCode = 500;
        if (error.message.includes('Insufficient credits')) statusCode = 402;
        else if (error.message.includes('User not found')) statusCode = 404;
        else if (error.message.includes('Invalid Content-Type') || error.message.includes('No image data')) statusCode = 400;
        else if (error.message.includes('Unauthorized') || error.message.includes('Invalid session token')) statusCode = 401; // Catch auth errors that might slip to general catch

        return NextResponse.json({ 
            error: `Internal server error: ${error.message}`,
            userInfo: { appleUserId, credits: finalCreditsForResponse } 
        }, { status: statusCode });
    }
}


function checkEnvVars(requiredEnvVars: string[], routeName?: string): { valid: boolean, missing?: string } {
  const prefix = routeName ? `${routeName}: ` : '';
  for (const varName of requiredEnvVars) {
      if (!process.env[varName]) {
          console.error(`${prefix}Missing required environment variable: ${varName}`);
          return { valid: false, missing: varName };
      }
  }
  // Optionally add more specific checks here if needed (e.g., check if private key looks valid)
  return { valid: true };
}



function getExtensionFromContentType(contentType: string | null): string {
  if (!contentType) return 'bin';
  const defaultExt = 'jpg'; // Keep jpg as default for images? Or 'bin'?
  switch (contentType.toLowerCase()) {
      case 'image/jpeg': return 'jpg';
      case 'image/png': return 'png';
      case 'image/gif': return 'gif';
      case 'image/webp': return 'webp';
      case 'image/svg+xml': return 'svg';
      // Add more common types if needed
      default:
          // Attempt to get extension from subtype more robustly
          const subtype = contentType.split('/')[1];
          // Handle potential parameters like 'charset=utf-8'
          return subtype ? subtype.split('+')[0].split(';')[0].trim() : defaultExt;
  }
}

function getS3Url(bucket: string, region: string, key: string | null | undefined): string | null {
   if (!key) return null;
   // Ensure key doesn't start with a '/' as it can cause issues with URL joining
   const effectiveKey = key.startsWith('/') ? key.substring(1) : key;
   // Use the virtual-hosted–style URL format
   return `https://${bucket}.s3.${region}.amazonaws.com/${effectiveKey}`;
}