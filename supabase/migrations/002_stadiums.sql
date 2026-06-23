CREATE TABLE IF NOT EXISTS public.stadiums (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name             text NOT NULL,
  team_id          uuid REFERENCES public.teams(id) NOT NULL,
  city             text NOT NULL,
  address          text NOT NULL,
  lat              double precision NOT NULL,
  lng              double precision NOT NULL,
  stamp_radius_m   integer NOT NULL DEFAULT 500,
  parking_info     text,
  seating_info     text,
  route_info       text,
  convenience_info text
);
