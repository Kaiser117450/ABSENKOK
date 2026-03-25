-- Phase 52: minimize public portal chooser exposure while preserving passwordless entry.
-- This additive patch keeps search_portal_employees(...) public, but narrows the result
-- contract to the chooser-safe DTO and tightens public query behavior:
--   - minimum normalized query length: 3 characters
--   - maximum normalized query length: 64 characters
--   - trigram fallback threshold: 4 characters
--   - LIMIT 5 result cap

CREATE OR REPLACE FUNCTION search_portal_employees(
  search_text text,
  limit_count integer DEFAULT 5
)
RETURNS TABLE (
  employee_id uuid,
  employee_name text,
  home_outlet_name text,
  "position" text,
  photo_url text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_query text;
  effective_limit integer;
BEGIN
  normalized_query := normalize_portal_search_text(search_text);

  IF normalized_query IS NULL THEN
    RETURN;
  END IF;

  normalized_query := left(normalized_query, 64);

  IF char_length(normalized_query) < 3 THEN
    RETURN;
  END IF;

  effective_limit := LEAST(GREATEST(COALESCE(limit_count, 5), 1), 5);

  RETURN QUERY
  WITH prefix_matches AS (
    SELECT
      e.id        AS employee_id,
      e.name      AS employee_name,
      o.name      AS home_outlet_name,
      e.position  AS position,
      e.photo_url AS photo_url,
      1           AS match_rank
    FROM employees e
    LEFT JOIN outlets o ON o.id = e.home_outlet_id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
      AND e.portal_search_name LIKE (normalized_query || '%')
    ORDER BY e.portal_search_name
    LIMIT effective_limit
  ),
  trgm_matches AS (
    SELECT
      e.id        AS employee_id,
      e.name      AS employee_name,
      o.name      AS home_outlet_name,
      e.position  AS position,
      e.photo_url AS photo_url,
      2           AS match_rank
    FROM employees e
    LEFT JOIN outlets o ON o.id = e.home_outlet_id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
      AND char_length(normalized_query) >= 4
      AND e.portal_search_name % normalized_query
      AND e.id NOT IN (SELECT pm.employee_id FROM prefix_matches pm)
    ORDER BY similarity(e.portal_search_name, normalized_query) DESC, e.name
    LIMIT effective_limit
  )
  SELECT
    combined.employee_id,
    combined.employee_name,
    combined.home_outlet_name,
    combined.position,
    combined.photo_url
  FROM (
    SELECT * FROM prefix_matches
    UNION ALL
    SELECT * FROM trgm_matches
  ) combined
  ORDER BY combined.match_rank, combined.employee_name
  LIMIT effective_limit;
END;
$$;

REVOKE ALL ON FUNCTION search_portal_employees(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION search_portal_employees(text, integer) TO anon, authenticated;
