import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

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
    // Verify caller is admin
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Create admin client with service_role key
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Verify the caller is an admin using their JWT.
    // We use verify_jwt=false at the gateway so the function always executes,
    // then we validate the JWT ourselves via getUser(token) with the
    // service_role client which has full auth.admin access.
    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: callerError } = await supabaseAdmin
      .auth.getUser(token);
    if (callerError || !caller) {
      const errMsg = callerError?.message ?? "Unknown auth error";
      console.error("getUser failed:", errMsg);
      return new Response(
        JSON.stringify({ error: `Unauthorized: ${errMsg}` }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const callerRole = caller.app_metadata?.app_role;
    if (callerRole !== "admin") {
      return new Response(
        JSON.stringify({ error: "Only admin can create accounts" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Parse request body
    const { email, name, outlet_id, outlet_ids, role } = await req.json();
    const requestedRole = role ?? "kepala_gerai";
    const allowedRoles = ["kepala_gerai", "area_supervisor"];
    if (!allowedRoles.includes(requestedRole)) {
      return new Response(
        JSON.stringify({ error: "Role tidak valid" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const rawOutletIds = Array.isArray(outlet_ids) ? outlet_ids : [outlet_id];
    const managedOutletIds = [
      ...new Set(
        rawOutletIds
          .filter((item) => typeof item === "string")
          .map((item) => item.trim())
          .filter((item) => item.length > 0),
      ),
    ];

    if (!email || !name || managedOutletIds.length === 0) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields: email, name, outlet_id/outlet_ids",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (requestedRole === "kepala_gerai" && managedOutletIds.length !== 1) {
      return new Response(
        JSON.stringify({
          error: "Kepala Gerai hanya boleh memiliki satu outlet",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: outletRows, error: outletError } = await supabaseAdmin
      .from("outlets")
      .select("id")
      .in("id", managedOutletIds)
      .eq("is_active", true);

    if (outletError) {
      return new Response(
        JSON.stringify({
          error: `Gagal memvalidasi outlet: ${outletError.message}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const validOutletIds = new Set((outletRows ?? []).map((row) => row.id));
    if (validOutletIds.size !== managedOutletIds.length) {
      return new Response(
        JSON.stringify({
          error: "Ada outlet yang tidak ditemukan atau tidak aktif",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Generate a secure random password (12 chars, alphanumeric + special)
    const chars =
      "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%";
    const array = new Uint8Array(12);
    crypto.getRandomValues(array);
    const generatedPassword = Array.from(
      array,
      (byte) => chars[byte % chars.length],
    ).join("");

    // Create user via admin API
    const { data: newUser, error: authError } = await supabaseAdmin.auth.admin
      .createUser({
        email: email,
        password: generatedPassword,
        email_confirm: true,
        app_metadata: {
          app_role: requestedRole,
          managed_outlet_id: managedOutletIds[0],
          managed_outlet_ids: managedOutletIds,
          must_change_password: true,
        },
        user_metadata: {
          name: name,
        },
      });

    if (authError) {
      const errorMessage = authError.message.includes("already been registered")
        ? "Email sudah terdaftar. Gunakan alamat email lain."
        : authError.message;
      return new Response(
        JSON.stringify({ error: errorMessage }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Return created user info + password (one-time)
    return new Response(
      JSON.stringify({
        success: true,
        user_id: newUser.user.id,
        email: email,
        name: name,
        role: requestedRole,
        outlet_id: managedOutletIds[0],
        outlet_ids: managedOutletIds,
        password: generatedPassword,
        created_at: newUser.user.created_at,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: `Server error: ${message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
