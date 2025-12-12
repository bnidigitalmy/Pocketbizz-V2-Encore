import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { action, userId, email, suspended } = await req.json();

    switch (action) {
      case "list": {
        // Get all users from auth.users
        const { data: users, error } = await supabase.auth.admin.listUsers();
        if (error) throw error;

        return new Response(
          JSON.stringify({ users: users.users }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "reset_password": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        // Generate temporary password
        const tempPassword = `TEMP-${Math.random().toString(36).slice(-8).toUpperCase()}`;

        // Update user password
        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        const { error } = await supabase.auth.admin.updateUserById(
          targetUserId,
          { password: tempPassword }
        );

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            tempPassword,
            message: "Password reset successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "suspend": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        // Ban user (suspend)
        const { error } = await supabase.auth.admin.updateUserById(
          targetUserId,
          { ban_duration: "876000h" } // ~100 years (effectively permanent)
        );

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "User suspended successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "activate": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        // Remove ban (activate)
        const { error } = await supabase.auth.admin.updateUserById(
          targetUserId,
          { ban_duration: "0" }
        );

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "User activated successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "delete": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        // Delete user
        const { error } = await supabase.auth.admin.deleteUser(targetUserId);

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "User deleted successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        error: error.message || "Internal server error" 
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

