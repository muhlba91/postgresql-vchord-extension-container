CREATE EXTENSION vchord CASCADE;

SELECT set_config('smoke.vchord_version', :'vchord_version', false);

DO $$
DECLARE
  installed text;
BEGIN
  SELECT extversion INTO installed FROM pg_extension WHERE extname = 'vchord';
  IF installed IS DISTINCT FROM current_setting('smoke.vchord_version') THEN
    RAISE EXCEPTION 'unexpected vchord version: %', installed;
  END IF;
END
$$;

CREATE TABLE items (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding)
SELECT ARRAY[random(), random(), random()]::vector FROM generate_series(1, 2000);
CREATE INDEX ON items USING vchordrq (embedding vector_l2_ops);

DO $$
DECLARE
  found integer;
BEGIN
  SELECT count(*) INTO found FROM (
    SELECT 1 FROM items ORDER BY embedding <-> '[0,0,0]' LIMIT 5
  ) AS nearest;
  IF found <> 5 THEN
    RAISE EXCEPTION 'unexpected nearest neighbor count: %', found;
  END IF;
END
$$;
