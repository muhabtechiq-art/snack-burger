-- حفظ منتج + إضافات داخل Transaction واحدة (Rollback تلقائي عند أي فشل)
-- نفّذ في Supabase → SQL Editor
-- لا يحذف أو يعدّل سياسات RLS الموجودة — فقط يضيف الدالة.

CREATE OR REPLACE FUNCTION public.save_product_with_addons(
  p_product jsonb,
  p_addons jsonb DEFAULT '[]'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_id bigint;
  v_addon jsonb;
BEGIN
  INSERT INTO public.products (
    id,
    name,
    price,
    description,
    category,
    image_url,
    restaurant_id
  )
  VALUES (
    (p_product->>'id')::bigint,
    trim(p_product->>'name'),
    (p_product->>'price')::numeric,
    NULLIF(trim(p_product->>'description'), ''),
    COALESCE(NULLIF(trim(p_product->>'category'), ''), 'general'),
    NULLIF(trim(p_product->>'image_url'), ''),
    COALESCE(NULLIF(trim(p_product->>'restaurant_id'), ''), 'snack_burger')
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price = EXCLUDED.price,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    image_url = EXCLUDED.image_url,
    restaurant_id = EXCLUDED.restaurant_id
  RETURNING id INTO v_id;

  DELETE FROM public.product_addons WHERE product_id = v_id;

  IF p_addons IS NOT NULL AND jsonb_typeof(p_addons) = 'array' THEN
    FOR v_addon IN SELECT value FROM jsonb_array_elements(p_addons)
    LOOP
      IF NULLIF(trim(v_addon->>'name'), '') IS NOT NULL THEN
        INSERT INTO public.product_addons (product_id, name, price)
        VALUES (
          v_id,
          trim(v_addon->>'name'),
          COALESCE((v_addon->>'price')::numeric, 0)
        );
      END IF;
    END LOOP;
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_product_with_addons(jsonb, jsonb)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
