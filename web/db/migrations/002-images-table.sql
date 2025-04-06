-- File: /web/db/migrations/002_create_images_table.sql
-- Migration to create the images table for tracking uploads (using SERIAL PK)

-- Remove UUID extension if it was only for this table
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create the images table
CREATE TABLE images (
  id SERIAL PRIMARY KEY,                  -- Use SERIAL for auto-incrementing integer PK
  apple_user_id TEXT NOT NULL,          -- Link to the user via Apple's unique ID
  original_s3_key TEXT NOT NULL,        -- S3 Key for the originally uploaded image
  processed_s3_key TEXT NULL,           -- S3 Key for the processed image (initially NULL)
  status TEXT NOT NULL DEFAULT 'UPLOADED', -- Tracking status: UPLOADED, PROCESSING, COMPLETED, FAILED
  prompt TEXT NULL,                     -- User-provided prompt (optional)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- Optional Foreign Key (uncomment if users.apple_user_id is UNIQUE and you want DB enforcement)
  -- CONSTRAINT fk_apple_user FOREIGN KEY(apple_user_id) REFERENCES users(apple_user_id) ON DELETE CASCADE
);

-- Add indexes for common query patterns
CREATE INDEX idx_images_apple_user_id ON images(apple_user_id);
CREATE INDEX idx_images_status ON images(status);


-- End of migration script