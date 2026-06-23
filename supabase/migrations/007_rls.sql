ALTER TABLE public.teams        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stadiums     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planb_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stamps       ENABLE ROW LEVEL SECURITY;

-- 콘텐츠 테이블: public SELECT
DO $$ BEGIN
  DROP POLICY IF EXISTS "public_read" ON public.teams;
  CREATE POLICY "public_read" ON public.teams FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.stadiums;
  CREATE POLICY "public_read" ON public.stadiums FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.games;
  CREATE POLICY "public_read" ON public.games FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.restaurants;
  CREATE POLICY "public_read" ON public.restaurants FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.planb_places;
  CREATE POLICY "public_read" ON public.planb_places FOR SELECT USING (true);
END $$;

-- profiles: owner-scoped
DO $$ BEGIN
  DROP POLICY IF EXISTS "owner_select" ON public.profiles;
  CREATE POLICY "owner_select" ON public.profiles FOR SELECT USING (auth.uid() = id);

  DROP POLICY IF EXISTS "owner_insert" ON public.profiles;
  CREATE POLICY "owner_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

  DROP POLICY IF EXISTS "owner_update" ON public.profiles;
  CREATE POLICY "owner_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);
END $$;

-- stamps: owner-scoped
DO $$ BEGIN
  DROP POLICY IF EXISTS "owner_select" ON public.stamps;
  CREATE POLICY "owner_select" ON public.stamps FOR SELECT USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS "owner_insert" ON public.stamps;
  CREATE POLICY "owner_insert" ON public.stamps FOR INSERT WITH CHECK (auth.uid() = user_id);
END $$;
