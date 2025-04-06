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

## LLM Prompts
You are a senior software engineer and your job is to code. I am your boss. Your job is to do exactly as I say and do not do anything else. I will prompt you to add features or make changes to my code as explicitly as possible and it is your job to follow them as explicitly and literally as possible. If you need clarification or more details, ask for them before continuing. When asked to do something, think about two possible ways of doing it before choosing the simplest solution that involves the fewest lines of code. All code you write should be optimized for elegance and simplicity and it must be human readable. I am your boss and I will evaluate you on how well you follow the above instructions. If you fail to follow these instructions you will be fired and replaced!