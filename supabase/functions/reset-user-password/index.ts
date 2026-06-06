import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Roles whose password an admin may reset. Employee-portal accounts are
// managed elsewhere and intentionally excluded.
const RESETTABLE_ROLES = ["admin", "kepala_gerai", "area_supervisor", "qc"];

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header" }, 401);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Validate the caller's JWT ourselves with the service_role client.
    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: callerError } = await supabaseAdmin
      .auth.getUser(token);
    if (callerError || !caller) {
      const errMsg = callerError?.message ?? "Unknown auth error";
      console.error("getUser failed:", errMsg);
      return jsonResponse({ error: `Unauthorized: ${errMsg}` }, 401);
    }

    const callerRole = caller.app_metadata?.app_role;
    if (callerRole !== "admin") {
      return jsonResponse({ error: "Hanya admin yang bisa reset password" }, 403);
    }

    const { user_id } = await req.json().catch(() => ({}));
    if (!user_id || typeof user_id !== "string") {
      return jsonResponse({ error: "Field user_id wajib diisi" }, 400);
    }

    // An admin cannot reset their own password through this tool — they must
    // use the normal change-password flow (prevents accidental self-lockout).
    if (user_id === caller.id) {
      return jsonResponse(
        { error: "Gunakan menu ganti password sendiri untuk akun Anda" },
        400,
      );
    }

    // Load the target and validate it is a resettable privileged account.
    const { data: targetResult, error: targetError } = await supabaseAdmin.auth
      .admin.getUserById(user_id);
    if (targetError || !targetResult?.user) {
      return jsonResponse({ error: "User tidak ditemukan" }, 404);
    }
    const target = targetResult.user;
    const targetRole = target.app_metadata?.app_role;
    if (!RESETTABLE_ROLES.includes(targetRole)) {
      return jsonResponse(
        { error: "Akun ini tidak bisa direset dari sini" },
        400,
      );
    }

    // Generate a secure random temporary password (12 chars). Mirrors the
    // alphabet used by create-admin-user (ambiguous chars removed).
    const chars =
      "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%";
    const bytes = new Uint8Array(12);
    crypto.getRandomValues(bytes);
    const tempPassword = Array.from(
      bytes,
      (b) => chars[b % chars.length],
    ).join("");

    // Preserve existing app_metadata, force a password change on next login.
    const nextMeta = {
      ...(target.app_metadata ?? {}),
      must_change_password: true,
    };

    const { error: updateError } = await supabaseAdmin.auth.admin
      .updateUserById(user_id, {
        password: tempPassword,
        app_metadata: nextMeta,
      });

    if (updateError) {
      return jsonResponse({ error: updateError.message }, 400);
    }

    // Accountability audit trail (who reset whom). Best-effort: the password
    // change already succeeded, so an audit failure must not fail the request.
    const { error: auditError } = await supabaseAdmin
      .from("admin_password_reset_log")
      .insert({
        target_user_id: user_id,
        target_email: target.email,
        target_role: targetRole,
        reset_by: caller.id,
        reset_by_email: caller.email,
      });
    if (auditError) {
      console.error("audit insert failed:", auditError.message);
    }

    return jsonResponse({
      success: true,
      user_id,
      email: target.email,
      password: tempPassword,
    }, 200);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: `Server error: ${message}` }, 500);
  }
});
