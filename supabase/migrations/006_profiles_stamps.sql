CREATE TABLE IF NOT EXISTS public.profiles (
  id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  favorite_team_id uuid REFERENCES public.teams(id),
  display_name     text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stamps (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stadium_id  uuid NOT NULL REFERENCES public.stadiums(id),
  stamped_at  timestamptz NOT NULL DEFAULT now(),
  lat         double precision NOT NULL,
  lng         double precision NOT NULL,
  UNIQUE(user_id, stadium_id)
);

-- 가입 시 profile 자동 생성
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles(id) VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
