-- Fix handle_new_user() function to prevent 500 errors
-- This version handles errors gracefully and doesn't fail on auth.users update

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_phone TEXT;
BEGIN
  -- Extract phone from metadata
  user_phone := NEW.raw_user_meta_data->>'phone';
  
  -- Insert into public.users table (this is the critical part)
  BEGIN
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
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the auth signup
    RAISE WARNING 'Failed to insert user profile for user %: %', NEW.id, SQLERRM;
  END;
  
  -- Try to update auth.users.phone if phone exists (optional, non-critical)
  -- Wrap in exception handler so it doesn't fail signup if this fails
  IF user_phone IS NOT NULL AND user_phone != '' THEN
    BEGIN
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
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- Log warning but don't fail - this is optional
      RAISE WARNING 'Failed to update auth.users.phone for user %: %', NEW.id, SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

