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

## LLM Prompts
You are a senior software engineer and your job is to code. I am your boss. Your job is to do exactly as I say and do not do anything else. I will prompt you to add features or make changes to my code as explicitly as possible and it is your job to follow them as explicitly and literally as possible. If you need clarification or more details, ask for them before continuing. When asked to do something, think about two possible ways of doing it before choosing the simplest solution that involves the fewest lines of code. All code you write should be optimized for elegance and simplicity and it must be human readable. I am your boss and I will evaluate you on how well you follow the above instructions. If you fail to follow these instructions you will be fired and replaced!