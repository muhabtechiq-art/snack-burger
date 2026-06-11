-- جدول المطاعم (multi-tenant) — نفّذ في Supabase Dashboard → SQL Editor
-- بعد التنفيذ: أدرج صف snack_burger أو حدّث slug/id ليطابق بياناتك.

create table if not exists public.restaurants (
  id text primary key,
  slug text not null unique,
  name text not null,
  logo_url text,
  banner_url text,
  primary_color text not null default '#8B0000',
  accent_color text not null default '#E1AD01',
  whatsapp_number text,
  order_routing_mode text not null default 'whatsapp',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists restaurants_slug_idx on public.restaurants (slug);

alter table public.restaurants enable row level security;

-- قراءة عامة للمطاعم النشطة (منيو الزبون)
drop policy if exists restaurants_public_read on public.restaurants;
create policy restaurants_public_read
  on public.restaurants
  for select
  using (is_active = true);

-- بيانات Snack Burger الافتراضية (عدّل id/whatsapp حسب مشروعك)
insert into public.restaurants (
  id,
  slug,
  name,
  primary_color,
  accent_color,
  whatsapp_number,
  order_routing_mode,
  is_active
) values (
  'snack_burger',
  'snack_burger',
  'Snack Burger',
  '#8B0000',
  '#E1AD01',
  '9647XXXXXXXXX',
  'whatsapp',
  true
)
on conflict (slug) do update set
  name = excluded.name,
  primary_color = excluded.primary_color,
  accent_color = excluded.accent_color,
  whatsapp_number = excluded.whatsapp_number,
  order_routing_mode = excluded.order_routing_mode,
  is_active = excluded.is_active,
  updated_at = now();

-- Realtime (اختياري — إن أردت تحديث ألوان/اسم المطعم لحظياً)
-- alter publication supabase_realtime add table public.restaurants;
