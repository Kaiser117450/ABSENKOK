-- ============================================================
-- PROMOTE TO ADMIN (Full Access)
-- ============================================================
-- Jalankan di Supabase SQL Editor
-- Ganti 1 nilai di bawah: EMAIL
-- ============================================================

DO $$
DECLARE
  -- ⬇️ GANTI DI SINI ⬇️
  v_email   TEXT := 'email.admin@gmail.com';   -- Email akun Supabase Auth
  -- ⬆️ GANTI DI ATAS ⬆️

  v_user_id UUID;
BEGIN
  -- 1. Cari user berdasarkan email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = LOWER(TRIM(v_email));

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '❌ User dengan email "%" tidak ditemukan di auth.users. Buat akun dulu di Supabase Auth Dashboard.', v_email;
  END IF;

  -- 2. Update app metadata — set admin, hapus scope outlet jika ada
  UPDATE auth.users
  SET raw_app_meta_data = (COALESCE(raw_app_meta_data, '{}'::jsonb)
    || '{"app_role": "admin"}'::jsonb)
    - 'managed_outlet_id'
    - 'managed_outlet_ids'
  WHERE id = v_user_id;

  RAISE NOTICE '✅ BERHASIL! % sekarang Admin (akses penuh)', v_email;
  RAISE NOTICE '   User ID: %', v_user_id;
  RAISE NOTICE '   → User bisa login di app sebagai Admin sekarang.';
END $$;
