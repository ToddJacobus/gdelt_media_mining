-- query design:

-- 	Select raster cells within a defined geometric circle where a given gdelt event is the centroid 

	-- NOTE:  use rast::geometry to get the geometry of a raster type in a tile
	-- This is called a 'cast'.  See: https://postgis.net/docs/reference.html
	-- eg: SELECT ST_Extent(rast::geometry) from uspop10_0 where rid = 1;
	-- This will return the bounding box for the raster tile with rid = 1

-- for thread on raster/polygon intersection, see: https://gis.stackexchange.com/questions/19856/intersecting-a-raster-with-a-polygon-using-postgis-artefact-error
-- this works for creating a buffer around each point:
	-- CREATE TABLE gdelt_bigquery_buffer_test AS SELECT globaleventid, st_buffer(geom, 10) FROM gdelt_bigquery;

-- Create table with buffers (100km) around each point: NOTE, 500 = 1000m for some reason...
	-- CREATE TABLE gdelt_bigquery_buffer_test AS SELECT globaleventid, st_buffer(geom::geography, 50000)::geometry as buffer FROM gdelt_bigquery;
	-- Here's the query I actually ran (completed in 57 seconds): 
CREATE TABLE gdelt_bigquery_buffer AS SELECT globaleventid, st_buffer(geom::geography, 50000)::geometry as geom FROM gdelt_bigquery_distinct;
CREATE TABLE gdelt_bigquery_buffer AS SELECT globaleventid, st_buffer(geom::geography, 50000) as geograhy FROM gdelt_bigquery_distinct;

-- make buffers of just US points
CREATE TABLE gdelt_bigquery_buffer AS 
SELECT p.globaleventid, st_buffer(p.geom::geography, 50000)::geometry as geom 
FROM (
	SELECT g.globaleventid, g.geom
	FROM gdelt_bigquery_distinct as g, us_outline as u
	WHERE st_within(g.geom, u.geom)
	) p;

-- use EXPLAIN ANALYZE to test queryies!

SELECT globaleventid, rast FROM uspop10_0 WHERE ST_Within(ST_Extent(rast::geometry), buffer)

SELECT ST_Value(rast,)


CREATE TABLE gdelt_event_pop AS

EXPLAIN ANALYZE
SELECT g.globaleventid, g.geom, p.rast --you may have to convert to geometry/geography
FROM gdelt_bigquery_distinct as g, uspop10_0 as p
WHERE st_intersects(g.geom, p.rast::geometry);

-- I ran this query to generate the pop table (40.3 seconds):
-- p.rast in the query below contains the 'raster' data type
-- can I get the value of the raster cell?
-- this probably creates a 'rast' column that represents the raster tile, not the cell

CREATE TABLE gdelt_event_pop AS
SELECT g.globaleventid, g.geom, p.rast --you may have to convert to geometry/geography
FROM gdelt_bigquery_distinct as g, uspop10_0 as p
WHERE st_intersects(g.geom, p.rast::geometry);

-- Let's try this again...

CREATE TABLE gdelt_event_pop AS
SELECT g.globaleventid, g.geom, st_value(p.rast) --you may have to convert to geometry/geography
FROM gdelt_bigquery_distinct as g, uspop10_0 as p
WHERE st_intersects(g.geom, p.rast::geometry);

-- didn't like this one... let's try this below:

 CREATE TABLE gdelt_event_pop AS
 SELECT globaleventid, 
        (gv).geom AS the_geom, 
        (gv).val
 FROM (SELECT globaleventid, 
              ST_Intersection(rast, the_geom) AS gv
       FROM uspop10_0,
            gdelt_bigquery_buffer
       WHERE ST_Intersects(rast, the_geom)
      );

 -- SELECT globaleventid, 
 --        --(gv).geom, 
 --        (gv).val
 -- FROM (
	-- SELECT g.globaleventid, ST_Intersection(p.rast::geometry, g.geom) AS gv
	-- FROM uspop10_0 as p, gdelt_bigquery_buffer as g
	-- WHERE ST_Intersects(rast, the_geom)
 --      ) buffer;

-- use methods defined here: https://postgis.net/2014/09/26/tip_count_of_pixel_values/
-- and here: https://gis.stackexchange.com/questions/19856/intersecting-a-raster-with-a-polygon-using-postgis-artefact-error

SELECT DISTINCT (pvc).VALUE
 FROM (SELECT ST_ValueCount(dem.rast,1) AS pvc
   FROM dem) AS f
 ORDER BY (pvc).VALUE;


 SELECT (pvc).VALUE, b.globaleventid
 FROM (
 	SELECT ST_ValueCount(r.rast) AS pvc, b.globaleventid
 	FROM uspop10_dat as r, gdelt_bigquery_buffer_us as b 
 	WHERE st_within(r.rast::geometry,b.geom)
 	) AS b

 --does this one work?
 	--QGIS keeps crashing... or maybe not, but I can't tell :(

 --selecting pixels without using buffer polygons
 	--use euclidean distance or something like it to get distance from point
 		--ST_Distance_Sphere see: https://postgis.net/docs/manual-1.4/ST_Distance_Sphere.html
 		--Returns distance between to lat/lon points (a,b) where st_distance_sphere(a,b)
 	--grab all pixel values in each cell that is within that distance
 		--use st_valuecount to get value and count of pixels within distnace of point
 		--may have to use st_PixelAsCentroid, see: https://postgis.net/docs/RT_ST_PixelAsCentroids.html
 		

SELECT (vc).VALUE, p.globaleventid
FROM(
	SELECT ST_ValueCount(r.rast) as vc, p.globaleventid
	FROM uspop10_dat as r, gdelt_bigquery_distinct as p
	WHERE ST_Distance_Sphere(r.rast::geometry,p.geom) < 1000
	) as p



-- using st_intersects/st_intersect

SELECT 
    r.rast 
FROM
    uspop10_dat as r, 
    gdelt_bigquery_buffer as b
WHERE
    ST_Intersects(r.rast, b.buffer)



 -- or this!
 -- this wont work because the buffer polygons when intersected with a raster cell is not a point geometry

 SELECT g.globaleventid, st_value(p.rast,st_intersection(p.rast::geometry,g.buffer))
 FROM gdelt_bigquery_buffer as g, uspop10_0 as p


-- or using st_clip:
-- I think this should work, but PostGIS is throwing an error:
--rt_band_load_offline_data: Access to offline bands disabled
-- CONTEXT:  PL/pgSQL function st_clip(raster,integer[],geometry,double precision[],boolean) line 8 at RETURN
-- This should be solvable.  See: https://dba.stackexchange.com/questions/97984/error-in-postgresql-postgis-access-to-offline-bands-disabled

-- uploaded the images WITH data (-R flag in raster2pgsql gdal command)
-- changed table names to use the new 'imaged' tables
-- ERROR: This consistently breaks QGIS...
	-- thoughts: too many buffer polygons?
		-- reduce this number?
		-- avoid using st_clip all together and use st_coveredby or st_within
SELECT g.globaleventid, st_clip(p.rast,g.buffer)
FROM gdelt_bigquery_buffer as g, uspop10_dat as p

--with us-only buffers

SELECT g.globaleventid, st_clip(p.rast,g.geom)
FROM gdelt_bigquery_buffer_us as g, uspop10_dat as p

--See for faster intersects: https://postgis.net/2014/03/14/tip_intersection_faster/

--Try st_coveredby method:
-- *** see above link for this code template ****
SELECT p.globaleventid, n.nei_name
 , CASE 
   WHEN ST_CoveredBy(p.geom, n.geom) 
   THEN p.geom 
   ELSE 
    ST_Multi(
      ST_Intersection(p.geom,n.geom)
      ) END AS geom 
 FROM parcels AS p 
   INNER JOIN neighborhoods AS n 
    ON ST_Intersects(p.geom, n.geom);




-- Try resampling the raster to reflect a larger area
	-- i.e. each pixel can represent a sampled population (100km x 100km square pixel size)
	-- Then just get the raster value that the point lies in.
	-- will this work or just give bogus population values?

-- *** Tutorial on speeding up raster data ***
	-- http://trac.osgeo.org/postgis/wiki/WKTRasterTutorial01
	-- https://gis.stackexchange.com/questions/43053/how-to-speed-up-queries-for-raster-databases



-- Add all raster values found in each of the cells that lie within the circle 
-- Use st_valuecount to sum values for rasters
select sum(st_valuecount('raster table'));

-- 	Insert this value into a column called "pop" within the gdelt_events_full table. 

