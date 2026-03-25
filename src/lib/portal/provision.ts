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

  const existingAuthUser = await findPortalAuthUserByEmail(authEmail);

  if (existingAuthUser) {
    assertReusablePortalAuthUser(existingAuthUser, employeeId);
    await updateSupabaseAuthAdminUser(existingAuthUser.id, userAttributes);
    return;
  }

  await createSupabaseAuthAdminUser(userAttributes);
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

async function findPortalAuthUserByEmail(email: string): Promise<PortalAuthUser | null> {
  const admin = createSupabaseAdminClient();
  const normalizedEmail = email.toLowerCase();
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
