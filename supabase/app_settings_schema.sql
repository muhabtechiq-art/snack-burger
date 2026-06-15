-- إعدادات عامة للتطبيق — وضع الصيانة وأرقام الطوارئ
-- نفّذ في Supabase Dashboard → SQL Editor

CREATE TABLE IF NOT EXISTS public.app_settings (
  id text PRIMARY KEY DEFAULT 'global',
  maintenance_mode boolean NOT NULL DEFAULT false,
  maintenance_title text NOT NULL DEFAULT 'نعتذر، النظام قيد التحديث',
  maintenance_message text NOT NULL DEFAULT
    'نعتذر عن إيقاف الخدمة بشكل مؤقت. نعمل حالياً على تحسين النظام لضمان أفضل تجربة لكم. يمكنكم إتمام الطلبات مباشرة عبر الأرقام التالية لحين عودة الخدمة. شكراً لتفهمكم.',
  phone_1 text NOT NULL DEFAULT '07777790170',
  phone_2 text NOT NULL DEFAULT '07891099899',
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.app_settings (id)
VALUES ('global')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_public_read ON public.app_settings;
CREATE POLICY app_settings_public_read
  ON public.app_settings
  FOR SELECT
  TO public
  USING (true);

DROP POLICY IF EXISTS app_settings_authenticated_update ON public.app_settings;
CREATE POLICY app_settings_authenticated_update
  ON public.app_settings
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS app_settings_authenticated_insert ON public.app_settings;
CREATE POLICY app_settings_authenticated_insert
  ON public.app_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- بث خفيف لصف واحد — لاكتشاف إلغاء الصيانة فوراً
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;

NOTIFY pgrst, 'reload schema';
