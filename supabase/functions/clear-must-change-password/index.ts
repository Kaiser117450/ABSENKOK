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
    // Get the user's JWT from Authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // Use the service_role client to verify the user's JWT.
    // We pass the raw token to getUser(token) — the global.headers
    // approach doesn't reliably set the auth context in Edge Functions.
    const adminClient = createClient(supabaseUrl, serviceRoleKey)
    const token = authHeader.replace('Bearer ', '')

    const { data: { user }, error: userError } = await adminClient.auth.getUser(token)
    if (userError || !user) {
      const errMsg = userError?.message ?? 'Unknown auth error'
      console.error('getUser failed:', errMsg)
      return new Response(
        JSON.stringify({ error: `Invalid token: ${errMsg}` }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Use service role to update app_metadata (can't be done client-side)
    const currentMeta = user.app_metadata || {}
    const { must_change_password, ...restMeta } = currentMeta

    const { error: updateError } = await adminClient.auth.admin.updateUserById(user.id, {
      app_metadata: { ...restMeta, must_change_password: false },
    })

    if (updateError) {
      return new Response(
        JSON.stringify({ error: updateError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Server error: ${err.message}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
