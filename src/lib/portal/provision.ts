import {
  createSupabaseAdminClient,
  updateSupabaseAuthAdminUser,
} from '../supabase/admin';

interface PortalEmployeeRow {
  id: string;
  name: string;
  is_active: boolean;
  archived_at: string | null;
}

interface PortalAccountRow {
  employee_id: string;
  auth_user_id: string;
}

export async function ensurePortalPasswordlessAccount(
  employeeId: string,
  authEmail: string,
  authPassword: string,
) {
  const admin = createSupabaseAdminClient();

  const { data: portalAccount, error: portalAccountError } = await admin
    .from('employee_portal_accounts')
    .select('employee_id, auth_user_id')
    .eq('employee_id', employeeId)
    .maybeSingle<PortalAccountRow>();

  if (portalAccountError) {
    throw new Error(`Failed to validate portal account mapping: ${portalAccountError.message}`);
  }

  if (!portalAccount) {
    throw new Error('Employee is not allowed to access the portal.');
  }

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
    if (existingAuthUser.id !== portalAccount.auth_user_id) {
      throw new Error('Portal account mapping does not match existing auth user.');
    }
    await updateSupabaseAuthAdminUser(existingAuthUser.id, userAttributes);
    return;
  }

  const { data: mappedAuthUser, error: mappedAuthUserError } = await admin.auth.admin.getUserById(
    portalAccount.auth_user_id,
  );

  if (mappedAuthUserError || !mappedAuthUser?.user) {
    throw new Error('Mapped portal auth user was not found.');
  }

  await updateSupabaseAuthAdminUser(portalAccount.auth_user_id, userAttributes);
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
