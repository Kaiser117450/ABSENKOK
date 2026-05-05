-- ============================================================
-- PROMOTE TO KEPALA GERAI
-- ============================================================
-- Jalankan di Supabase SQL Editor
-- Ganti 2 nilai di bawah: EMAIL dan NAMA_GERAI
-- ============================================================

DO $$
DECLARE
  -- ⬇️ GANTI DI SINI ⬇️
  v_email       TEXT := 'email.kepala@gmail.com';     -- Email akun Supabase Auth
  v_nama_gerai  TEXT := 'Ahmad Yani';                 -- Nama gerai (case-insensitive)
  -- ⬆️ GANTI DI ATAS ⬆️

  v_user_id     UUID;
  v_outlet_id   UUID;
  v_outlet_name TEXT;
BEGIN
  -- 1. Cari user berdasarkan email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = LOWER(TRIM(v_email));

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '❌ User dengan email "%" tidak ditemukan di auth.users. Buat akun dulu di Supabase Auth Dashboard.', v_email;
  END IF;

  -- 2. Cari outlet berdasarkan nama (case-insensitive)
  SELECT id, name INTO v_outlet_id, v_outlet_name
  FROM public.outlets
  WHERE LOWER(name) = LOWER(TRIM(v_nama_gerai))
    AND is_active = true;

  IF v_outlet_id IS NULL THEN
    RAISE EXCEPTION '❌ Gerai "%" tidak ditemukan atau tidak aktif. Gerai yang tersedia: Ahmad Yani, Office, Pakerisan, Panjer, Pulau Kawe', v_nama_gerai;
  END IF;

  -- 3. Update app metadata
  UPDATE auth.users
  SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object(
         'app_role', 'kepala_gerai',
         'managed_outlet_id', v_outlet_id::text,
         'managed_outlet_ids', jsonb_build_array(v_outlet_id::text)
       )
  WHERE id = v_user_id;

  RAISE NOTICE '✅ BERHASIL! % sekarang Kepala Gerai di "%"', v_email, v_outlet_name;
  RAISE NOTICE '   User ID: %', v_user_id;
  RAISE NOTICE '   Outlet ID: %', v_outlet_id;
  RAISE NOTICE '   → User bisa login di app sebagai Kepala Gerai sekarang.';
END $$;
