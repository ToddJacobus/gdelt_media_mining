#to run in the QGIS console, or executed from script
#see https://gis.stackexchange.com/questions/244803/using-raster2pgsql-in-python-console-of-qgis/245227#245227

#('postgresql://rjacobus:{}@gis4870.msudenver.edu:5432/rjacobus'.format(password))
#password = getpass.getpass(prompt='Password: ')

import os
import subprocess

db_name = 'gis4870'
db_host = 'msudenver.edu'
db_user = 'rjacobus'
db_password = getpass.getpass(prompt='Password: ')

data_path = "/Users/Jacobus/Documents/Mapping/census_data/usgrid_data_2010/geotiff"
# Set pg password environment variable - others can be included in the statement
os.environ['PGPASSWORD'] = db_password 

# Build command string
cmd = 'raster2pgsql -s 4326 -C -F -t auto /Users/Jacobus/Documents/Mapping/census_data/usgrid_data_2010/geotiff/*.tif schema.target_table | psql -U {} -d {} -h {} -p 5432'.format(db_user,db_name,db_host)

# Execute
subprocess.call(cmd, shell=True)


#alternate method
import psycopg2
import subprocess 
import sys, os

input_path = " C:\\qgis_cloud_data\\"
#Change to the location of pgsql bin folder
os.environ['PATH'] = r';C:\pgsql\9.6\bin'
os.environ['PGHOST'] = 'localhost'
os.environ['PGPORT'] = '9008'
os.environ['PGUSER'] = 'postgres'
os.environ['PGPASSWORD'] = 'dbpass'
os.environ['PGDATABASE'] = 'dbname'

for raster in os.listdir(input_path):
    if raster.endswith(".tif"):
       name = raster.split(".tif")[0]
       # Print the foound tiff name
       print(name)     
       raster = os.path.join(input_path, raster)                    
       # Print the full path of the tiff raster
       print(raster)
       rastername = str(name)
       rasterlayer = rastername.lower()
       conn = psycopg2.connect(database="dbname", user="postgres", host="localhost", password="dbpass", port=9008)
       cursor = conn.cursor()
       cmds = 'raster2pgsql -s 3857 -t auto "' + raster + '" |psql'
       subprocess.call(cmds, shell=True)