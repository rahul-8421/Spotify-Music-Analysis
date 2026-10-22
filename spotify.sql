USE spotify_db;
DROP TABLE IF EXISTS tracks;

CREATE TABLE tracks (
  track_id VARCHAR(30),
  artists VARCHAR(500),
  album_name VARCHAR(500),
  track_name VARCHAR(500),
  popularity INT,
  duration_ms INT,
  explicit VARCHAR(10),
  danceability FLOAT,
  energy FLOAT,
  `key` INT,
  loudness FLOAT,
  mode INT,
  speechiness FLOAT,
  acousticness FLOAT,
  instrumentalness FLOAT,
  liveness FLOAT,
  valence FLOAT,
  tempo FLOAT,
  time_signature INT,
  track_genre VARCHAR(100),
  duration_min FLOAT,
  popularity_bucket VARCHAR(10)
);
USE spotify_db;

ALTER TABLE tracks
  MODIFY artists TEXT,
  MODIFY album_name TEXT,
  MODIFY track_name TEXT;

TRUNCATE TABLE tracks;
SELECT COUNT(*) FROM tracks;
SELECT artists, track_name FROM tracks WHERE track_name LIKE '%Enamor%' LIMIT 5;
  SELECT COUNT(*) FROM spotify_db.tracks;
select * from tracks;

#Checking Data
USE spotify_db;

SELECT COUNT(*) AS total_rows, COUNT(DISTINCT track_id) AS unique_songs FROM tracks;
SELECT explicit, COUNT(*) FROM tracks GROUP BY explicit;

# Create View
CREATE OR REPLACE VIEW tracks_unique AS
SELECT * FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY track_id ORDER BY popularity DESC) AS rn
  FROM tracks t
) x
WHERE rn = 1;

#1 Top 10 genres by average popularity
SELECT track_genre, ROUND(AVG(popularity),1) AS avg_pop, COUNT(*) AS songs
FROM tracks
GROUP BY track_genre
ORDER BY avg_pop DESC
LIMIT 10;

#2 Effect of energy on popularity
SELECT 
  CASE WHEN energy >= 0.7 THEN 'High Energy'
       WHEN energy >= 0.4 THEN 'Medium Energy'
       ELSE 'Low Energy' END AS energy_level,
  COUNT(*) AS songs,
  ROUND(AVG(popularity),1) AS avg_pop
FROM tracks_unique
GROUP BY energy_level
ORDER BY avg_pop DESC;

#3 Explicit vs non-explicit
SELECT explicit, COUNT(*) AS songs, ROUND(AVG(popularity),1) AS avg_pop
FROM tracks_unique
GROUP BY explicit;

#4 Top 10 artists with at least 20 songs
SELECT artists, COUNT(*) AS songs, ROUND(AVG(popularity),1) AS avg_pop
FROM tracks_unique
GROUP BY artists
HAVING COUNT(*) >= 20
ORDER BY avg_pop DESC
LIMIT 10;

#5 Best song duration
SELECT ROUND(duration_min) AS minutes, COUNT(*) AS songs, ROUND(AVG(popularity),1) AS avg_pop
FROM tracks_unique
GROUP BY minutes
HAVING songs > 100
ORDER BY minutes;

#6 Audio profile of High vs Low songs (core insight)
SELECT popularity_bucket,
       COUNT(*) AS songs,
       ROUND(AVG(danceability),3) AS danceability,
       ROUND(AVG(energy),3)       AS energy,
       ROUND(AVG(valence),3)      AS valence,
       ROUND(AVG(acousticness),3) AS acousticness,
       ROUND(AVG(loudness),2)     AS loudness
FROM tracks_unique
GROUP BY popularity_bucket;

#7 Share of songs in each popularity bucket
SELECT popularity_bucket,
       COUNT(*) AS songs,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_songs
FROM tracks_unique
GROUP BY popularity_bucket
ORDER BY songs DESC;

#8 Genres with the highest share of hit songs
SELECT track_genre,
       COUNT(*) AS songs,
       ROUND(SUM(popularity_bucket = 'High') * 100.0 / COUNT(*), 1) AS pct_high
FROM tracks
GROUP BY track_genre
HAVING COUNT(*) >= 100
ORDER BY pct_high DESC
LIMIT 10;

#9 Artists that beat the overall average (CTE)
WITH overall AS (
  SELECT AVG(popularity) AS avg_all FROM tracks_unique
)
SELECT t.artists,
       COUNT(*) AS songs,
       ROUND(AVG(t.popularity),1) AS avg_pop,
       ROUND(AVG(t.popularity) - o.avg_all, 1) AS above_average_by
FROM tracks_unique t
CROSS JOIN overall o
GROUP BY t.artists, o.avg_all
HAVING COUNT(*) >= 15
ORDER BY above_average_by DESC
LIMIT 10;

#10 Popularity quartiles (NTILE)
SELECT quartile,
       COUNT(*) AS songs,
       MIN(popularity) AS min_pop,
       MAX(popularity) AS max_pop,
       ROUND(AVG(danceability),3) AS danceability,
       ROUND(AVG(energy),3) AS energy
FROM (
  SELECT *, NTILE(4) OVER (ORDER BY popularity) AS quartile
  FROM tracks_unique
) q
GROUP BY quartile
ORDER BY quartile;