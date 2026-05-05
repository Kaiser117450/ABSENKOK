import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Derive a stable hidden auth email from the employee UUID.
 * This email is never displayed to the employee and is derived from a stable id,
 * not from mutable display fields like name or employee code.
 */
function derivePortalEmail(employeeId: string): string {
  return `employee+${employeeId}@portal.absenkok.internal`
}

/**
 * Generate a 32-character random password using the runtime's CSPRNG.
 * The password is never returned to the caller — it is stored only in
 * Supabase Auth (hashed) and re-derived deterministically by the portal
 * sign-in flow from PORTAL_SECRET + employee id. Generating a random
 * placeholder here defends against admins accidentally provisioning
 * accounts with weak/guessable passwords if the Astro flow is bypassed.
 */
function generateRandomPassword(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  let out = ''
  for (let i = 0; i < bytes.length; i += 1) {
    out += alphabet[bytes[i] % alphabet.length]
  }
  return out
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Require Authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client with service_role key (server-side only, never exposed to clients)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify the caller using their JWT — must be an admin
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user: caller }, error: callerError } = await supabaseUser.auth.getUser()
    if (callerError || !caller) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    const callerRole = caller.app_metadata?.app_role
    if (callerRole !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Only admin can provision employee portal accounts' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body — only accept employee_id. Password is generated
    // server-side so the caller cannot ship a weak/guessable value.
    const body = await req.json()
    const { employee_id } = body as { employee_id?: string }

    if (!employee_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: employee_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const password = generateRandomPassword()

    // Load employee row server-side — source of truth, not caller-supplied display fields
    const { data: employee, error: employeeError } = await supabaseAdmin
      .from('employees')
      .select('id, name, is_active, archived_at')
      .eq('id', employee_id)
      .single()

    if (employeeError || !employee) {
      return new Response(
        JSON.stringify({ error: 'Employee not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Block inactive or archived employees
    if (!employee.is_active || employee.archived_at !== null) {
      return new Response(
        JSON.stringify({ error: 'Cannot provision portal access for an inactive or archived employee' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Block if portal mapping already exists for this employee
    const { data: existingMapping, error: mappingError } = await supabaseAdmin
      .from('employee_portal_accounts')
      .select('employee_id')
      .eq('employee_id', employee_id)
      .maybeSingle()

    if (mappingError) {
      return new Response(
        JSON.stringify({ error: `Failed to check existing portal account: ${mappingError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (existingMapping) {
      return new Response(
        JSON.stringify({ error: 'A portal account is already provisioned for this employee' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Derive hidden auth email from stable employee UUID
    const syntheticEmail = derivePortalEmail(employee_id)

    // Create auth user with employee_portal role and employee_id in app_metadata
    const { data: newUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: syntheticEmail,
      password,
      email_confirm: true,
      app_metadata: {
        app_role: 'employee_portal',
        employee_id,
      },
      user_metadata: {
        employee_name: employee.name,
      },
    })

    if (authError) {
      const message = authError.message.includes('already been registered')
        ? 'A portal auth user already exists for this employee id. Check for orphaned auth records.'
        : authError.message
      return new Response(
        JSON.stringify({ error: message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Insert the one-to-one mapping row into employee_portal_accounts
    const { error: insertError } = await supabaseAdmin
      .from('employee_portal_accounts')
      .insert({
        employee_id,
        auth_user_id: newUser.user.id,
        auth_email: syntheticEmail,
        provisioned_by: caller.id,
      })

    if (insertError) {
      // Auth user was created but mapping insert failed — attempt cleanup
      await supabaseAdmin.auth.admin.deleteUser(newUser.user.id)
      return new Response(
        JSON.stringify({ error: `Failed to save portal account mapping: ${insertError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return a small success payload — never echo back the password
    return new Response(
      JSON.stringify({
        success: true,
        employee_id,
        employee_name: employee.name,
        auth_user_id: newUser.user.id,
        created_at: newUser.user.created_at,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Server error: ${err.message}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
