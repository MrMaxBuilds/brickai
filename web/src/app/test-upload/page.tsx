'use client';

import { useState, FormEvent } from 'react';

export default function TestUploadPage() {
  const [file, setFile] = useState<File | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    
    if (!file) {
      setError('Please select an image file');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Create form data object
      const formData = new FormData();
      formData.append('image', file);

      // Send the request to the API endpoint
      const response = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Failed to upload image');
      }

      setImageUrl(data.imageUrl);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to upload image');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto p-6 mt-10">
      <h1 className="text-2xl font-bold mb-6">Test Image Upload</h1>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block mb-2 text-sm font-medium">
            Select an image to upload
          </label>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => setFile(e.target.files?.[0] || null)}
            className="block w-full text-sm border rounded-lg cursor-pointer focus:outline-none"
          />
        </div>

        <button
          type="submit"
          disabled={loading || !file}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg disabled:opacity-50"
        >
          {loading ? 'Uploading...' : 'Upload Image'}
        </button>
      </form>

      {error && (
        <div className="mt-4 p-3 bg-red-100 text-red-700 rounded-lg">
          {error}
        </div>
      )}

      {imageUrl && (
        <div className="mt-6">
          <h2 className="text-lg font-semibold mb-2">Uploaded Image URL:</h2>
          <div className="p-3 bg-gray-100 rounded-lg break-all">
            <a href={imageUrl} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">
              {imageUrl}
            </a>
          </div>
          <div className="mt-4">
            <h3 className="text-md font-semibold mb-2">Image Preview:</h3>
            <img 
              src={imageUrl} 
              alt="Uploaded" 
              className="max-w-full h-auto rounded-lg border" 
            />
          </div>
        </div>
      )}
    </div>
  );
} 