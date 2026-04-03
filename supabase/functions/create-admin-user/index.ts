import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify caller is admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client with service_role key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify the caller is an admin using their JWT.
    // Extract the raw token and pass it directly to getUser() — the
    // global.headers approach doesn't reliably set the auth context
    // inside Edge Functions, causing "invalid JWT" 401 errors.
    const token = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: callerError } = await supabaseAdmin.auth.getUser(token)
    if (callerError || !caller) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    const callerRole = caller.app_metadata?.app_role
    if (callerRole !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Only admin can create accounts' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { email, name, outlet_id } = await req.json()
    if (!email || !name || !outlet_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, name, outlet_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate a secure random password (12 chars, alphanumeric + special)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%'
    const array = new Uint8Array(12)
    crypto.getRandomValues(array)
    const generatedPassword = Array.from(array, (byte) => chars[byte % chars.length]).join('')

    // Create user via admin API
    const { data: newUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: generatedPassword,
      email_confirm: true,
      app_metadata: {
        app_role: 'kepala_gerai',
        managed_outlet_id: outlet_id,
        must_change_password: true,
      },
      user_metadata: {
        name: name,
      },
    })

    if (authError) {
      const errorMessage = authError.message.includes('already been registered')
        ? 'Email sudah terdaftar. Gunakan alamat email lain.'
        : authError.message
      return new Response(
        JSON.stringify({ error: errorMessage }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return created user info + password (one-time)
    return new Response(
      JSON.stringify({
        success: true,
        user_id: newUser.user.id,
        email: email,
        name: name,
        outlet_id: outlet_id,
        password: generatedPassword,
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
