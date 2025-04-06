CREATE TABLE users (
  id SERIAL PRIMARY KEY, -- Or UUID PRIMARY KEY DEFAULT uuid_generate_v4() if you prefer UUIDs
  apple_user_id TEXT UNIQUE NOT NULL, -- Apple's unique subject identifier
  apple_refresh_token TEXT NULL,      -- Store the refresh token securely
  email TEXT NULL,                    -- User's email (might be null or the private relay address)
  full_name TEXT NULL,                -- User's full name (if captured and needed)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for faster lookups by Apple User ID
CREATE INDEX idx_users_apple_user_id ON users(apple_user_id);
