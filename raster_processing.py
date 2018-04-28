import rasterio
import numpy

dataPath = "/Users/Jacobus/Documents/Mapping/Census_Data/usgrid_data_2010/geotiff/uspop10.tif"

with rasterio.open(dataPath) as src:
	w = src.read(1, window=Window(0,0,512,256))

print(w.shape)

