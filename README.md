# BrickAI

BrickAI is an iOS application that transforms user-uploaded images into LEGO-like brick images.

## Architecture

The application consists of two main components:

1. **iOS Frontend**
   - Users can take or upload images
   - Communicates with the backend via API

2. **Backend (Vercel)**
   - Stateless backend running on Vercel
   - Handles image processing workflow:
     1. Receives images from iOS app
     2. Uploads images to AWS for public URL generation
     3. Processes images through OpenAI's 4o model API
     4. Returns transformed LEGO-style images to the frontend

## API Endpoints

### Image Upload
- **URL**: `/api/upload`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Request Body**: Form data with an `image` field containing the image file
- **Response**: JSON with the image URL on S3
  ```json
  {
    "success": true,
    "imageUrl": "https://bucket-name.s3.amazonaws.com/uploads/timestamp-filename",
    "message": "Image uploaded successfully"
  }
  ```

Example curl command:
```curl -X POST -F "image=@/Users/maxu/Documents/Projects/brickai/web/public/brick.jpg" http://localhost:3000/api/upload```

## Environment Configuration

Copy the `.env.local.example` file to `.env.local` and fill in your AWS credentials:
```
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_S3_BUCKET_NAME=your-bucket-name
```

# Authentication Setup (Sign in with Apple + Supabase + Vercel)

This outlines the steps required to configure the authentication flow for this project, which uses Sign in with Apple on an iOS client, a Next.js backend deployed on Vercel, and a Supabase Postgres database managed via Vercel integration.

## Overview

The authentication flow follows the OAuth 2.0 Authorization Code Grant:

1.  **iOS Client**: Initiates "Sign in with Apple", receives an `authorizationCode`.
2.  **iOS Client**: Sends the `authorizationCode` to the backend endpoint `/api/auth/apple/callback`.
3.  **Backend**:
    * Generates a `client_secret` JWT signed with the Apple private key.
    * Exchanges the `authorizationCode` and `client_secret` with Apple's `/auth/token` endpoint.
    * Receives an Apple `id_token` and `refresh_token`.
    * Verifies the Apple `id_token`.
    * Upserts user information (Apple User ID, email) and stores/updates the Apple `refresh_token` in the Supabase database (`users` table).
    * Generates its own backend session token (JWT signed with `BACKEND_JWT_SECRET`).
    * Returns the backend session token to the iOS client.
4.  **iOS Client**: Stores the backend session token securely (Keychain).
5.  **iOS Client**: Includes the backend session token in the `Authorization: Bearer` header for subsequent API calls (e.g., `/api/upload`).
6.  **Backend**: Verifies the backend session token on protected routes.
7.  **(Refresh Flow)**: When the backend session token expires (detected via 401 error), the client calls `/api/auth/refresh`. The backend uses the stored Apple `refresh_token` to get new Apple tokens and issues a new backend session token to the client.

## 1. Apple Developer Portal Setup

Configure the necessary identifiers and keys in the [Apple Developer Portal](https://developer.apple.com/):

1.  **App ID Configuration**:
    * Ensure your iOS App ID (e.g., `com.yourcompany.BrickAI`) has the "Sign in with Apple" capability enabled.
    * Note your **Bundle ID** (`APPLE_BUNDLE_ID`).
    * Note your **Team ID** (`APPLE_TEAM_ID`).
2.  **Services ID Creation**:
    * Register a new **Services ID** (e.g., `com.yourdomain.brickai.service`).
    * Enable "Sign in with Apple" for this Services ID.
    * Configure it, associating your App ID as the Primary App ID. Add relevant domains (your Vercel deployment domain) and Return URLs (`https://<your-vercel-app>/api/auth/apple/callback`).
    * Note the **Services ID Identifier** (`APPLE_SERVICE_ID`).
3.  **Private Key Generation**:
    * Register a new **Key**.
    * Enable the "Sign in with Apple" service for this key.
    * Associate it with your Primary App ID.
    * **Download the private key file (`.p8`) immediately** (this is your only chance) and store it securely.
    * Note the **Key ID** (`APPLE_KEY_ID`).

## 2. Supabase Setup (via Vercel Integration)

Set up the Postgres database using the Vercel integration:

1.  **Add Integration**: In your Vercel project dashboard, navigate to the **Storage** tab.
2.  **Create Database**: Click "Create Database" (or similar) and select **Supabase** (or Postgres provided by Supabase/Neon if the UI differs slightly).
3.  **Configure**: Choose a database name and region.
4.  **Connect**: Vercel will provision the database and automatically add the required connection environment variables to your Vercel project settings.

## 3. Backend Environment Variables (Vercel Setup)

Configure the following environment variables in your Vercel project settings (Settings -> Environment Variables) for the Production, Preview, and Development environments as needed:

* `APPLE_BUNDLE_ID`: Your iOS App's Bundle ID (from Apple Setup Step 1).
* `APPLE_TEAM_ID`: Your Apple Developer Team ID (from Apple Setup Step 1).
* `APPLE_SERVICE_ID`: Your Services ID identifier (from Apple Setup Step 2).
* `APPLE_KEY_ID`: The Key ID for your downloaded `.p8` key (from Apple Setup Step 3).
* `APPLE_PRIVATE_KEY`: The **entire content** of the downloaded `.p8` private key file. **Important:** Copy the full text, including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`. When pasting into Vercel, ensure literal newline characters are represented as `\n` (the backend code handles converting these back to actual newlines).
* `SUPABASE_URL`: Automatically added by the Vercel Supabase integration. Contains the URL to your Supabase project API.
* `SUPABASE_SERVICE_ROLE_KEY`: Automatically added by the Vercel Supabase integration. This is a **secret admin key** for your Supabase project – treat it with extreme care. The backend uses this for direct database operations.
* `BACKEND_JWT_SECRET`: A **user-generated** strong, random secret string (use `openssl rand -base64 64` or a password manager to generate). Used by the backend to sign its own session tokens. Keep this secret!

*(Note: The Vercel Supabase integration also adds other variables like `SUPABASE_ANON_KEY`, `POSTGRES_URL`, etc. The backend currently uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` for database access via `@supabase/supabase-js`.)*

## 4. Database Schema

The backend requires a `users` table in your Supabase Postgres database. You can use a migration tool or manually apply the following SQL schema as a starting point (see `/db/migrations/001-users.sql`):


## LLM Prompts
You are a senior software engineer and your job is to code. I am your boss. Your job is to do exactly as I say and do not do anything else. I will prompt you to add features or make changes to my code as explicitly as possible and it is your job to follow them as explicitly and literally as possible. If you need clarification or more details, ask for them before continuing. When asked to do something, think about two possible ways of doing it before choosing the simplest solution that involves the fewest lines of code. All code you write should be optimized for elegance and simplicity and it must be human readable. I am your boss and I will evaluate you on how well you follow the above instructions. If you fail to follow these instructions you will be fired and replaced!