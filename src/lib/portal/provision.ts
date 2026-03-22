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
    await updateSupabaseAuthAdminUser(existingAuthUser.id, userAttributes);
    return;
  }

  await createSupabaseAuthAdminUser(userAttributes);
}

async function findPortalAuthUserByEmail(email: string) {
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
      return existingAuthUser;
    }

    if (listedUsers.users.length < perPage) {
      return null;
    }

    page += 1;
  }
}
