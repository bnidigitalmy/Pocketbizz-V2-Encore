-- Add phone column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone TEXT;

-- Create index for phone lookups (optional, but useful for searches)
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE phone IS NOT NULL;

-- Update the trigger function to also capture phone from metadata
-- Note: This function updates both public.users and auth.users.phone
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_phone TEXT;
BEGIN
  -- Extract phone from metadata
  user_phone := NEW.raw_user_meta_data->>'phone';
  
  -- Insert into public.users table
  INSERT INTO public.users (id, email, full_name, phone)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    user_phone
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, users.full_name),
    phone = COALESCE(EXCLUDED.phone, users.phone),
    updated_at = NOW();
  
  -- Also update auth.users.phone if phone exists in metadata
  -- This allows phone to show in Supabase Auth dashboard
  -- Note: This requires SECURITY DEFINER and proper permissions
  -- Check for duplicate phone before updating
  IF user_phone IS NOT NULL AND user_phone != '' THEN
    -- Only update if phone doesn't already exist for another user
    IF NOT EXISTS (
      SELECT 1 FROM auth.users 
      WHERE phone = user_phone 
      AND id != NEW.id
    ) THEN
      UPDATE auth.users 
      SET phone = user_phone,
          updated_at = NOW()
      WHERE id = NEW.id;
    ELSE
      -- Phone already exists - log warning but don't fail
      RAISE WARNING 'Phone % already exists for another user, skipping update for user %', user_phone, NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to sync phone from metadata to auth.users for existing users
-- Run this manually to update existing users' phone numbers
-- Handles duplicate phone numbers by skipping updates if phone already exists
CREATE OR REPLACE FUNCTION public.sync_phone_from_metadata()
RETURNS void AS $$
DECLARE
  user_record RECORD;
  phone_value TEXT;
BEGIN
  -- Loop through users with phone in metadata but not in auth.users.phone
  FOR user_record IN 
    SELECT au.id, au.raw_user_meta_data->>'phone' as metadata_phone
    FROM auth.users au
    WHERE au.raw_user_meta_data->>'phone' IS NOT NULL 
      AND au.raw_user_meta_data->>'phone' != ''
      AND (au.phone IS NULL OR au.phone = '')
  LOOP
    phone_value := user_record.metadata_phone;
    
    -- Check if phone already exists for another user
    IF NOT EXISTS (
      SELECT 1 FROM auth.users 
      WHERE phone = phone_value 
      AND id != user_record.id
    ) THEN
      -- Safe to update - no duplicate
      UPDATE auth.users 
      SET phone = phone_value,
          updated_at = NOW()
      WHERE id = user_record.id;
    ELSE
      -- Phone already exists for another user - skip this user
      -- Log or handle as needed (for now, just skip)
      RAISE NOTICE 'Skipping user % - phone % already exists for another user', user_record.id, phone_value;
    END IF;
  END LOOP;
    
  -- Also update public.users table (no unique constraint here, so safe)
  UPDATE public.users pu
  SET phone = (
    SELECT au.raw_user_meta_data->>'phone'
    FROM auth.users au
    WHERE au.id = pu.id
  ),
  updated_at = NOW()
  WHERE EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = pu.id
    AND au.raw_user_meta_data->>'phone' IS NOT NULL
    AND au.raw_user_meta_data->>'phone' != ''
  )
  AND (pu.phone IS NULL OR pu.phone = '');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

