-- ============================================================
-- PROMOTE TO AREA SUPERVISOR
-- ============================================================
-- Jalankan di Supabase SQL Editor
-- Ganti 2 nilai di bawah: EMAIL dan NAMA_GERAI_LIST
-- ============================================================

DO $$
DECLARE
  -- GANTI DI SINI
  v_email           TEXT := 'email.supervisor@gmail.com';
  v_nama_gerai_list TEXT[] := ARRAY['Ahmad Yani', 'Panjer'];
  -- GANTI DI ATAS

  v_user_id      UUID;
  v_outlet_ids   UUID[];
  v_outlet_names TEXT[];
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = LOWER(TRIM(v_email));

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User dengan email "%" tidak ditemukan di auth.users.', v_email;
  END IF;

  SELECT
    array_agg(o.id ORDER BY o.name),
    array_agg(o.name ORDER BY o.name)
  INTO v_outlet_ids, v_outlet_names
  FROM public.outlets o
  WHERE o.is_active = TRUE
    AND EXISTS (
      SELECT 1
      FROM unnest(v_nama_gerai_list) AS requested_name
      WHERE LOWER(o.name) = LOWER(TRIM(requested_name))
    );

  IF COALESCE(array_length(v_outlet_ids, 1), 0) <> array_length(v_nama_gerai_list, 1) THEN
    RAISE EXCEPTION 'Tidak semua gerai ditemukan/aktif. Diminta: % | Ditemukan: %',
      v_nama_gerai_list,
      COALESCE(v_outlet_names, ARRAY[]::TEXT[]);
  END IF;

  UPDATE auth.users
  SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object(
         'app_role', 'area_supervisor',
         'managed_outlet_id', v_outlet_ids[1]::text,
         'managed_outlet_ids', to_jsonb(
           ARRAY(SELECT outlet_id::text FROM unnest(v_outlet_ids) AS outlet_id)
         )
       )
  WHERE id = v_user_id;

  RAISE NOTICE 'BERHASIL! % sekarang Area Supervisor untuk gerai: %',
    v_email,
    array_to_string(v_outlet_names, ', ');
  RAISE NOTICE 'User ID: %', v_user_id;
END $$;
