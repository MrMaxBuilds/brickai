// File: web/src/app/api/images/route.ts
// Route to list images, fixed 'any' types

import { NextRequest, NextResponse } from "next/server";
import jwt from "jsonwebtoken";
import { createClient } from "@supabase/supabase-js";
import { UserInfo } from "@/user/types";

// --- Environment Variable Check (remains the same) ---
const requiredEnvVars = [
  "BACKEND_JWT_SECRET",
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "AWS_S3_BUCKET_NAME",
  "AWS_REGION",
];
function checkEnvVars(): { valid: boolean; missing?: string } {
  /* ... same as before ... */
  for (const varName of requiredEnvVars) {
    if (!process.env[varName]) return { valid: false, missing: varName };
  }
  return { valid: true };
}
// --- End Environment Variable Check ---

// Helper getS3Url (remains the same)
function getS3Url(
  bucket: string,
  region: string,
  key: string | null | undefined
): string | null {
  /* ... same as before ... */
  if (!key) return null;
  return `https://${bucket}.s3.${region}.amazonaws.com/${key}`;
}

// Define ImageResponse interface (using Int for ID if needed, but backend sends whatever DB has - usually number/string)
// Client-side Swift struct handles the concrete type (Int).
interface ImageResponseItem {
  id: number | string; // Changed from UUID
  status: string;
  prompt: string | null;
  createdAt: string;
  originalImageUrl: string | null;
  processedImageUrl: string | null;
}

// --- Main GET Handler ---
export async function GET(req: NextRequest) {
  let appleUserId: string;

  const envCheck = checkEnvVars();
  if (!envCheck.valid) {
    return NextResponse.json(
      { error: `Config Error: Missing ${envCheck.missing}` },
      { status: 500 }
    );
  }
  const backendJwtSecret = process.env.BACKEND_JWT_SECRET as string;
  const supabaseUrl = process.env.SUPABASE_URL as string;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string;
  const awsS3BucketName = process.env.AWS_S3_BUCKET_NAME as string;
  const awsRegion = process.env.AWS_REGION as string;

  try {
    // --- 1. Verify Backend Session Token ---
    const authHeader = req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return NextResponse.json(
        { error: "Unauthorized: Missing Authorization header." },
        { status: 401 }
      );
    }
    const sessionToken = authHeader.substring(7);

    try {
      const decoded = jwt.verify(sessionToken, backendJwtSecret, {
        algorithms: ["HS256"],
        issuer: "BrickAIBackend",
      });
      if (
        typeof decoded === "object" &&
        decoded !== null &&
        typeof decoded.sub === "string"
      ) {
        appleUserId = decoded.sub;
      } else {
        throw new Error(
          "Invalid token payload structure or missing/invalid sub claim."
        );
      }
      console.log(
        `Images Route: Verified session token for Apple User ID (sub): ${appleUserId}`
      );
    } catch (err: unknown) {
      // Use 'unknown'
      let errorMessage = "Unauthorized: Invalid session token.";
      if (err instanceof Error) {
        // Check if it's an Error
        console.error(
          "Images Route: Backend Session Token Verification Error:",
          err.message
        );
        if (err.name === "TokenExpiredError") {
          errorMessage = "Unauthorized: Session has expired.";
        }
      } else {
        console.error(
          "Images Route: Backend Session Token Verification Error: Caught non-Error object"
        );
      }
      return NextResponse.json({ error: errorMessage }, { status: 401 });
    }
    // --- End Token Verification ---

    // --- 2. Initialize Supabase Client (remains the same) ---
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // --- 2.5 Fetch User Credits --- ADDED STEP
    console.log(`Images Route: Fetching credits for user ${appleUserId}`);
    const { data: userData, error: userFetchError } = await supabase
      .from("users")
      .select("usage_credits")
      .eq("apple_user_id", appleUserId)
      .single();

    if (userFetchError) {
      console.error(`Images Route: Error fetching user ${appleUserId} for credit count:`, userFetchError);
      return NextResponse.json({ error: "Error fetching user data." }, { status: 500 });
    }
    if (!userData) {
      console.warn(`Images Route: User ${appleUserId} not found when fetching credits.`);
      // Consider if this should be a 404 or if image fetching should proceed with 0 credits for userInfo
      return NextResponse.json({ error: "User not found." }, { status: 404 });
    }
    const userCredits = userData.usage_credits;
    console.log(`Images Route: User ${appleUserId} has ${userCredits} credits.`);

    // --- 3. Fetch Image Records from Database ---
    console.log(`Images Route: Fetching images for user: ${appleUserId}`);
    // Select specific columns including the SERIAL 'id'
    const { data: imagesData, error: dbError } = await supabase
      .from("images")
      .select(
        "id, status, prompt, created_at, original_s3_key, processed_s3_key"
      )
      .eq("apple_user_id", appleUserId)
      .order("created_at", { ascending: false });

    if (dbError) {
      console.error("Images Route: Supabase select error:", dbError);
      return NextResponse.json(
        { error: `Failed to fetch images: ${dbError.message}` },
        { status: 500 }
      );
    }
    if (!imagesData) {
      return NextResponse.json([]);
    } // Return empty array if no images

    // --- 4. Process Results and Construct URLs ---
    // Map DB results to the response structure
    const responseImages: ImageResponseItem[] = imagesData.map((img) => ({
      id: img.id, // Pass the ID (number or string depending on client)
      status: img.status,
      prompt: img.prompt,
      createdAt: img.created_at,
      originalImageUrl: getS3Url(
        awsS3BucketName,
        awsRegion,
        img.original_s3_key
      ),
      processedImageUrl: getS3Url(
        awsS3BucketName,
        awsRegion,
        img.processed_s3_key
      ),
    }));

    // --- 5. Return Response ---
    console.log(
      `Images Route: Returning ${responseImages.length} images for user ${appleUserId}.`
    );
    const userInfo: UserInfo = {
        appleUserId: appleUserId,
        credits: userCredits
    };
    return NextResponse.json({ images: responseImages, userInfo: userInfo });
  } catch (err: unknown) {
    // Use 'unknown'
    console.error("Images Route: Unhandled Error:", err);
    const message =
      err instanceof Error
        ? err.message
        : "Internal server error while fetching images.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
