CREATE TABLE IF NOT EXISTS public.teams (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name            text NOT NULL,
  short_name      text NOT NULL,
  abbr            text NOT NULL UNIQUE,
  primary_color   text NOT NULL,
  secondary_color text NOT NULL
);
