import Link from "next/link";

export default function Home() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100">
      <h1 className="text-8xl font-extrabold text-center text-gray-800 tracking-tight mb-8">
        Brick<span className="text-blue-600">AI</span>
      </h1>
      
      <div className="mt-6">
        <Link 
          href="/test-upload" 
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          Test Image Upload
        </Link>
      </div>
    </div>
  );
}
