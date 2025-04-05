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