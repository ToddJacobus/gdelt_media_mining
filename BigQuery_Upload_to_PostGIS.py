credentials_path = "/Users/Jacobus/Documents/Python/BigQuery_Credentials/My Project-dd3f5afafb0b.json"

# Imports the Google Cloud client library
from google.cloud import bigquery
import google.datalab.bigquery as bq
import pandas
# import pandas.gbq

from shapely.geometry import Point
import pandas as pd
import geopandas as gpd
from geopandas import GeoSeries, GeoDataFrame
from geoalchemy2 import Geometry, WKTElement
from sqlalchemy import *
import getpass

import datetime

# Instantiates a client
client = bigquery.Client.from_service_account_json(credentials_path)


#make the big query
#column names to query:
    # GLOBALEVENTID
    # SQLDATE -- YYYYMMDD
    # ActionGeo_Lat
    # ActionGeo_Lon
    # NumArticles
    # AvgTone
#where date = [...]
#where location type = city-level
#where action_geo is not null

#create a list of dates with YYYYMMDD format for the first of each month for the last 5 years
	#dates cannot extend past the current date
	#for example: 20130101, 20130201, 20130301
	#for each month we add 100 to the sqldate integer

def getDateList(startYear,endYear): #endYear is exclusive ending
	dates_dict = {}
	dates = []
	years = int(endYear-startYear)
	for year in range(years):
		year = str(startYear+year)
		dates_dict[year] = ['01','02','03','04','05','06','07','08','09','10','11','12']
	for year,months in dates_dict.items():
		for month in months:
			dates.append(year+month+'01')
	return dates	#return list of dates 


def getData(datelist):
	password = getpass.getpass(prompt='Password: ')
	engine = create_engine('postgresql://rjacobus:{}@gis4870.msudenver.edu:5432/rjacobus'.format(password))

	current = 1

	for date in datelist:
		print("Getting data for date ({}) {} of {} @ {}".format(date,current,len(datelist),datetime.datetime.today()))
		current+=1

		query_job = client.query("""
			SELECT GLOBALEVENTID, SQLDATE, ActionGeo_Lat, ActionGeo_Long, NumArticles, AvgTone, ActionGeo_Type
			FROM `gdelt-bq.full.events`
			WHERE SQLDATE = {} AND ActionGeo_Lat is NOT NULL AND ActionGeo_Lat <> 0 AND ActionGeo_Long <> 0 AND (ActionGeo_Type = 3 OR ActionGeo_Type = 4)
			""".format(date))

		query_dict = {
			'globaleventid':[],
			'sqldate':[],
			'ActionGeo_Lat':[],
			'ActionGeo_Long':[],
			'NumArticles':[],
			'AvgTone':[],
			'ActionGeo_Type':[]
		}

		results = query_job.result()
		# print(type(results))
		nrows = 0
		for row in results:
			nrows+=1
			query_dict['globaleventid'].append(row.GLOBALEVENTID)
			query_dict['sqldate'].append(row.SQLDATE)
			query_dict['ActionGeo_Lat'].append(row.ActionGeo_Lat)
			query_dict['ActionGeo_Long'].append(row.ActionGeo_Long)
			query_dict['NumArticles'].append(row.NumArticles)
			query_dict['AvgTone'].append(row.AvgTone)
			query_dict['ActionGeo_Type'].append(row.ActionGeo_Type)
		print("Retrieved {} rows...".format(nrows))
		# print("Dictionary keys: {}".format(query_dict.keys()))
		    
		df = pandas.DataFrame.from_dict(query_dict)

		# make geometry column
		geometry = [Point(xy) for xy in zip(df['ActionGeo_Long'],df['ActionGeo_Lat'])]
		gdf = GeoDataFrame(df,geometry=geometry)

		#see for GeoAlchemy solution: https://gis.stackexchange.com/questions/239198/geopandas-dataframe-to-postgis-table-help

		#fix geometry column
		gdf['geom'] = gdf['geometry'].apply(lambda x: WKTElement(x.wkt,srid=4326))
		#drop the old geometry column
		gdf.drop('geometry',1,inplace=True)

		#append data to data table
		gdf.to_sql('gdelt_bigquery_full',engine, if_exists='append',index=False,
			dtype={
			    'geom': Geometry('POINT',srid=4326)
			})



getData(getDateList(2014,2018))

# for k,v in getDateList(2013,2018).items(): print(k,v)
# print(getDateList(2013,2018))


