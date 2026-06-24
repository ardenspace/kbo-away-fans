CREATE TABLE IF NOT EXISTS public.planb_places (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  stadium_id   uuid REFERENCES public.stadiums(id) NOT NULL,
  name         text NOT NULL,
  category     text NOT NULL,
  address      text,
  lat          double precision,
  lng          double precision,
  source_url   text NOT NULL,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
