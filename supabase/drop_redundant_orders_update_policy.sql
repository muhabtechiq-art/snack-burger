-- =============================================================================
-- Drop redundant orders UPDATE policy — live DB cleanup
-- Manual run only: Supabase Dashboard → SQL Editor
-- Branch intent: saas-v2
--
-- Context:
--   The repo (c01_orders_rls_migration.sql) defines a single UPDATE policy:
--     orders_c01_update_authenticated_admin
--     → orders_matches_admin_profile(restaurant_id, slug)
--
--   Some live databases also have:
--     orders_c01_update_authenticated_tenant
--     → catalog_matches_admin_profile(...)   [catalog helper — wrong table]
--   That policy is NOT in supabase/** migrations and appears to be a stray
--   duplicate from manual runs or copy-paste from catalog RLS (c02).
--
-- Flutter path:
--   Order status / rejection updates use SECURITY DEFINER RPCs only:
--     admin_update_order_status, admin_update_order_rejection_reason
--   (lib/services/supabase_order_service.dart — no direct .update on orders)
--
-- This script:
--   - Drops the redundant tenant-named UPDATE policy only
--   - Keeps orders_c01_update_authenticated_admin (defense in depth for API)
--
-- Does NOT change:
--   - orders_c01_update_authenticated_admin
--   - SELECT policies (authenticated tenant / anon interim)
--   - INSERT / DELETE policies
--   - Any RPC or other table
-- =============================================================================

DROP POLICY IF EXISTS orders_c01_update_authenticated_tenant
  ON public.orders;

NOTIFY pgrst, 'reload schema';
