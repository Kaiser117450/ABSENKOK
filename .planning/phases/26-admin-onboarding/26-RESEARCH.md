# Phase 26 Research: Admin Onboarding + Notification Polish

## Context
Goal: Admin can create new Kepala Gerai accounts directly from the app with secure server-side user creation and share credentials via WhatsApp, and generate a PDF audit trail.

## Standard Stack

**1. Server-Side User Creation**
- **Supabase CLI**: For generating and deploying Edge Functions locally and to production.
- **Supabase Edge Functions**: Deno based, TypeScript.
- **supabase_flutter**: use `supabase.functions.invoke()`

**2. Credentials Sharing via WhatsApp**
- **url_launcher (^6.3.0)**: Use standard `https://wa.me/?text=` or `whatsapp://send?text=`.
- **share_plus**: Already installed in pubspec.yaml, use as a fallback when WhatsApp is not explicitly installed.

**3. PDF Audit Trail**
- **pdf**: Already installed, use `package:pdf/widgets.dart` (as `pw`).
- **printing**: Already installed, use for preview and standard sharing (`Printing.sharePdf` or `Printing.layoutPdf`).
- **path_provider**: Already installed, use for temporary file storage if manual saving is required.

## Architecture Patterns

**1. Secure Admin Creation via Edge Function**
- Create a new Supabase Edge Function: `supabase functions new create-admin-user`.
- The Mobile App calls `await supabase.functions.invoke('create-admin-user', body: {'email': email, 'name': name, 'outlet_id': outletAssignment});`.
- Within the Edge Function, load the `SUPABASE_SERVICE_ROLE_KEY` to bypass Row Level Security.
- Edge Function creates the user Auth account using `supabaseAdmin.auth.admin.createUser({ email, password, email_confirm: true })`.
- Edge Function explicitly sets user metadata roles (e.g., `role: 'kepala_gerai'`).
- Edge Function inserts the corresponding record into `employees` (or `users`) table.
- Edge Function generates the password (or accepts it securely) and returns it in the HTTP response so the admin can share it exactly once.

**2. Flutter WhatsApp Deep Linking**
- App constructs a secure credentials message: `URL-encoded string` containing "Akses Aplikasi Absenkok: Email: [e], Password: [p]".
- Use `url_launcher` to launch `whatsapp://send?text=xyz`.
- If `canLaunchUrl()` is false, fallback to generic sharing using `Share.share(message)`.

**3. Flutter PDF Audit Trail**
- Use `pdf` package to construct `pw.Document`.
- Include App Logo, Timestamp, Admin metadata, and the newly created user's credentials and outlet assignment.
- Export as raw bytes and render using the `printing` plugin to directly trigger native OS print/save-to-PDF dialogs.

## Don't Hand-Roll

- **Do NOT** embed the `SUPABASE_SERVICE_ROLE_KEY` inside the Flutter app. Ever. It is an extreme security risk.
- **Do NOT** try to log the admin out, create the user, and log back in. Use Edge Functions for backend admin actions.
- **Do NOT** hand-roll custom share intents in Kotlin/Java. Use `url_launcher` or `share_plus`.
- **Do NOT** try to compose PDF binaries manually block by block. Always use the declarative `pw.*` widgets native to the `pdf` package.
- **Do NOT** generate un-hashed passwords manually on the client; either let Supabase auto-generate or use a strong cryptographically secure random string generator in the Edge Function / App. 

## Common Pitfalls

- **CORS in Edge Functions**: Forgetting to implement standard CORS headers (`Access-Control-Allow-Origin: *`) in the Deno script. `supabase.functions.invoke` essentially performs an HTTP POST, and missing CORS will result in silent UI failures or exception throws in Flutter. Always return CORS headers including for `OPTIONS` requests.
- **Missing Android Manifest Queries**: For `whatsapp://` deep link checks via `canLaunchUrl()`, Android 11+ requires explicitly adding `<queries><package android:name="com.whatsapp" /></queries>` in `android/app/src/main/AndroidManifest.xml`. Without this, the launcher refuses to detect the app.
- **Async Gap in Flutter Share**: After doing `await`, ensuring that the `BuildContext` is still mounted before attempting to show a Snackbar reporting sharing failure.
- **PDF Font Loading**: Using standard fonts sometimes drops characters for certain symbols. Stick to standard OpenSans provided via rootBundle if needed, or rely on `Printing` library's default embedded fonts.
- **Edge Function Environment Variables**: Forgetting to push `.env` variables containing the service role key to the Supabase remote project before triggering from the production app.

## Code Examples

**Edge Function CORS Handlers**
```typescript
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Inside simple handler:
if (req.method === 'OPTIONS') {
  return new Response('ok', { headers: corsHeaders })
}
```

**Edge Function Admin User Creation (Deno/Typescript)**
```typescript
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

const { data: user, error: authError } = await supabaseAdmin.auth.admin.createUser({
  email: email,
  password: generatedPassword,
  email_confirm: true,
  user_metadata: { role: 'kepala_gerai' }
})
```

**Flutter App Invocation**
```dart
final response = await supabase.functions.invoke(
  'create-admin-user',
  body: {
    'email': 'new_gerai@example.com',
    'name': 'Budi',
    'outlet_id': 1
  },
);
```

**WhatsApp Sharing**
```dart
final text = Uri.encodeComponent("Credentials for your new account:...");
final url = Uri.parse("whatsapp://send?text=$text");

if (await canLaunchUrl(url)) {
  await launchUrl(url);
} else {
  // Fallback
  await Share.share("Credentials:...");
}
```

**PDF Document Creation**
```dart
final pdf = pw.Document();
pdf.addPage(
  pw.Page(
    build: (pw.Context context) => pw.Center(
      child: pw.Text('Audit Trail Document', style: const pw.TextStyle(fontSize: 24)),
    ),
  ),
);
await Printing.sharePdf(bytes: await pdf.save(), filename: 'audit_trail.pdf');
```
