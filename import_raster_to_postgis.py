#see for a tutorial: https://duncanjg.wordpress.com/2012/11/20/the-basics-of-postgis-raster/
#see for details on gdal/raster2pgsql options: http://postgis.refractions.net/docs/using_raster.xml.html#RT_Loading_Rasters


import psycopg2  
import subprocess 
import sys, os
import getpass
import json

input_path = "/Users/Jacobus/Documents/Mapping/census_data/usgrid_data_2010/geotiff"

password = getpass.getpass(prompt='Password: ')
db_credentials_path = '/Users/Jacobus/Documents/Python/msu_denver_db_creds.json'
with open(db_credentials_path,'r') as f:
	db_conn_dict = json.load(f)
db_conn_dict['password'] = password

connection = psycopg2.connect(**db_conn_dict)

for raster in os.listdir(input_path):    
	if raster.endswith(".tif"):
		name = raster.split(".tif")[0]
		raster = os.path.join(input_path, raster)

	rastername = str(name)
	rasterlayer = rastername.lower()

	# cursor = conn.cursor()
	cmds = 'raster2pgsql -s 4326 -t 2000x2000 "' + raster + '" |psql'
	subprocess.call(cmds, shell=True)

connection.close()