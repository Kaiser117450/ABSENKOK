import {
  createSupabaseAdminClient,
  createSupabaseAuthAdminUser,
  updateSupabaseAuthAdminUser,
} from '../supabase/admin';

interface PortalEmployeeRow {
  id: string;
  name: string;
  is_active: boolean;
  archived_at: string | null;
}

interface PortalAuthUser {
  id: string;
  email?: string | null;
  email_confirmed_at?: string | null;
  app_metadata?: Record<string, unknown> | null;
}

export async function ensurePortalPasswordlessAccount(
  employeeId: string,
  authEmail: string,
  authPassword: string,
) {
  const admin = createSupabaseAdminClient();

  const { data: employee, error: employeeError } = await admin
    .from('employees')
    .select('id, name, is_active, archived_at')
    .eq('id', employeeId)
    .single<PortalEmployeeRow>();

  if (employeeError || !employee) {
    throw new Error('Employee not found for portal sign-in.');
  }

  if (!employee.is_active || employee.archived_at !== null) {
    throw new Error('Employee is inactive or archived.');
  }

  const userAttributes = {
    email: authEmail,
    password: authPassword,
    email_confirm: true,
    app_metadata: {
      app_role: 'employee_portal',
      employee_id: employeeId,
    },
    user_metadata: {
      employee_name: employee.name,
    },
  };

  const existingAuthUser = await findPortalAuthUserByEmail(authEmail, employeeId);

  if (existingAuthUser) {
    assertReusablePortalAuthUser(existingAuthUser, employeeId);
    await updateSupabaseAuthAdminUser(existingAuthUser.id, userAttributes);
    await upsertPortalAccountMapping(employeeId, existingAuthUser.id, authEmail);
    return;
  }

  const newAuthUser = await createSupabaseAuthAdminUser(userAttributes);
  // Persist the (employee_id -> auth_user_id) mapping so the next sign-in
  // hits the indexed `employee_portal_accounts` lookup instead of falling
  // through to the legacy `auth.admin.listUsers` paginated sweep.
  await upsertPortalAccountMapping(employeeId, newAuthUser.id, authEmail);
}

async function upsertPortalAccountMapping(
  employeeId: string,
  authUserId: string,
  authEmail: string,
) {
  const admin = createSupabaseAdminClient();
  const { error } = await admin
    .from('employee_portal_accounts')
    .upsert(
      {
        employee_id: employeeId,
        auth_user_id: authUserId,
        auth_email: authEmail,
      },
      { onConflict: 'employee_id' },
    );
  if (error) {
    throw new Error(`Failed to persist portal account mapping: ${error.message}`);
  }
}

function assertReusablePortalAuthUser(existingAuthUser: PortalAuthUser, employeeId: string) {
  const role = getMetadataString(existingAuthUser.app_metadata, 'app_role');
  const boundEmployeeId = getMetadataString(existingAuthUser.app_metadata, 'employee_id');

  if (!existingAuthUser.email_confirmed_at) {
    throw new Error('Existing hidden portal auth user is not confirmed. Manual recovery required.');
  }

  if (role !== 'employee_portal') {
    throw new Error('Existing hidden portal auth user has an unexpected app role.');
  }

  if (boundEmployeeId?.toLowerCase() !== employeeId.toLowerCase()) {
    throw new Error('Existing hidden portal auth user has a conflicting employee binding.');
  }
}

function getMetadataString(
  metadata: Record<string, unknown> | null | undefined,
  key: string,
) {
  const value = metadata?.[key];
  return typeof value === 'string' && value.length > 0 ? value : null;
}

/**
 * Locate the auth user that owns this hidden portal email.
 *
 * Previously this paged through `auth.admin.listUsers` 200-at-a-time on
 * every login retry, which scaled linearly with the size of `auth.users`.
 * The `employee_portal_accounts` mapping table now provides a direct
 * `employee_id -> auth_user_id` lookup, so a single indexed `select`
 * replaces an unbounded sweep. The list-users fallback is kept only for
 * accounts created before the mapping table existed (it should normally
 * be empty after the next login).
 */
async function findPortalAuthUserByEmail(
  email: string,
  employeeId: string,
): Promise<PortalAuthUser | null> {
  const admin = createSupabaseAdminClient();
  const normalizedEmail = email.toLowerCase();

  const { data: mapping, error: mappingError } = await admin
    .from('employee_portal_accounts')
    .select('auth_user_id')
    .eq('employee_id', employeeId)
    .maybeSingle<{ auth_user_id: string }>();

  if (mappingError) {
    throw new Error(`Failed to read portal account mapping: ${mappingError.message}`);
  }

  if (mapping?.auth_user_id) {
    const { data: byId, error: byIdError } = await admin.auth.admin.getUserById(mapping.auth_user_id);
    if (byIdError) {
      throw new Error(`Failed to load mapped portal auth user: ${byIdError.message}`);
    }
    if (byId.user) {
      return {
        id: byId.user.id,
        email: byId.user.email,
        email_confirmed_at: byId.user.email_confirmed_at,
        app_metadata: byId.user.app_metadata as Record<string, unknown> | null,
      };
    }
  }

  // Legacy fallback: account exists in auth.users but no mapping row yet.
  // First try the cheap one-page lookup; only escalate to a full sweep if
  // the auth user is on a later page (rare).
  const perPage = 200;
  let page = 1;

  while (true) {
    const { data: listedUsers, error: listUsersError } = await admin.auth.admin.listUsers({
      page,
      perPage,
    });

    if (listUsersError) {
      throw new Error(`Failed to inspect existing portal auth users: ${listUsersError.message}`);
    }

    const existingAuthUser = listedUsers.users.find(
      (user) => user.email?.toLowerCase() === normalizedEmail,
    );

    if (existingAuthUser) {
      return {
        id: existingAuthUser.id,
        email: existingAuthUser.email,
        email_confirmed_at: existingAuthUser.email_confirmed_at,
        app_metadata: existingAuthUser.app_metadata as Record<string, unknown> | null,
      };
    }

    if (listedUsers.users.length < perPage) {
      return null;
    }

    page += 1;
  }
}
