-- Add admin_users table for secure admin access control
-- Replaces hardcoded email whitelist in code
-- ============================================================================

-- Create admin_users table
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  granted_by UUID REFERENCES users(id),
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON admin_users(user_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_admin_users_active ON admin_users(is_active) WHERE is_active = TRUE;

-- Enable RLS
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies for admin_users table
-- Policy 1: Users can check their own admin status (needed for AdminHelper.isAdmin())
-- This allows any user to check if they are admin
DROP POLICY IF EXISTS "Users can check own admin status" ON admin_users;
CREATE POLICY "Users can check own admin status"
ON admin_users
FOR SELECT
USING (user_id = auth.uid());

-- Policy 2: Admins can view all admin_users (for management)
-- This allows existing admins to see all admin users (for admin management UI)
-- Uses OR condition so both policies work together
DROP POLICY IF EXISTS "Admins can view all admin_users" ON admin_users;
CREATE POLICY "Admins can view all admin_users"
ON admin_users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admin_users au 
    WHERE au.user_id = auth.uid() AND au.is_active = TRUE
  )
);

-- Only admins can insert (grant admin access)
DROP POLICY IF EXISTS "Admins can grant admin access" ON admin_users;
CREATE POLICY "Admins can grant admin access"
ON admin_users
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admin_users au 
    WHERE au.user_id = auth.uid() AND au.is_active = TRUE
  )
);

-- Only admins can update (revoke/grant)
DROP POLICY IF EXISTS "Admins can update admin_users" ON admin_users;
CREATE POLICY "Admins can update admin_users"
ON admin_users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admin_users au 
    WHERE au.user_id = auth.uid() AND au.is_active = TRUE
  )
);

-- Only admins can delete (revoke admin access)
DROP POLICY IF EXISTS "Admins can revoke admin access" ON admin_users;
CREATE POLICY "Admins can revoke admin access"
ON admin_users
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admin_users au 
    WHERE au.user_id = auth.uid() AND au.is_active = TRUE
  )
);

-- Create function to check if user is admin
-- Version 1: With UUID parameter
CREATE OR REPLACE FUNCTION is_admin(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM admin_users 
    WHERE user_id = user_uuid AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Version 2: Without parameter (uses auth.uid() internally)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM admin_users 
    WHERE user_id = auth.uid() AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION is_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;

-- Add comment
COMMENT ON TABLE admin_users IS 'Table for managing admin user access. Replaces hardcoded email whitelist.';
COMMENT ON FUNCTION is_admin(UUID) IS 'Check if a user has admin access. Uses SECURITY DEFINER for RLS bypass.';
