CREATE TABLE IF NOT EXISTS public.games (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id        text NOT NULL UNIQUE,
  home_team_id   uuid REFERENCES public.teams(id) NOT NULL,
  away_team_id   uuid REFERENCES public.teams(id) NOT NULL,
  stadium_id     uuid REFERENCES public.stadiums(id) NOT NULL,
  scheduled_at   timestamptz NOT NULL,
  status         text NOT NULL DEFAULT 'scheduled'
                 CHECK (status IN ('scheduled','in_progress','finished','cancelled','postponed')),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
