-- ============================================================
-- DEMOTE / REVOKE ROLE
-- ============================================================
-- Jalankan di Supabase SQL Editor
-- Menghapus akses admin/kepala gerai dari user
-- Ganti 1 nilai di bawah: EMAIL
-- ============================================================

DO $$
DECLARE
  -- ⬇️ GANTI DI SINI ⬇️
  v_email   TEXT := 'email.user@gmail.com';   -- Email akun yang ingin di-demote
  -- ⬆️ GANTI DI ATAS ⬆️

  v_user_id  UUID;
  v_old_role TEXT;
BEGIN
  -- 1. Cari user berdasarkan email
  SELECT id, raw_app_meta_data->>'app_role'
  INTO v_user_id, v_old_role
  FROM auth.users
  WHERE email = LOWER(TRIM(v_email));

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '❌ User dengan email "%" tidak ditemukan di auth.users.', v_email;
  END IF;

  IF v_old_role IS NULL THEN
    RAISE NOTICE '⚠️ User % tidak memiliki role apapun. Tidak ada yang perlu diubah.', v_email;
    RETURN;
  END IF;

  -- 2. Hapus app_role dan scope outlet dari metadata
  UPDATE auth.users
  SET raw_app_meta_data = raw_app_meta_data
    - 'app_role'
    - 'managed_outlet_id'
    - 'managed_outlet_ids'
  WHERE id = v_user_id;

  RAISE NOTICE '✅ BERHASIL! Role "%" dicabut dari %', v_old_role, v_email;
  RAISE NOTICE '   User ID: %', v_user_id;
  RAISE NOTICE '   → User tidak bisa login ke dashboard admin lagi.';
END $$;
