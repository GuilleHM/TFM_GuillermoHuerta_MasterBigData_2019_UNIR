## Este "script" nos permite obtener un mapa con las elevaciones y las pendientes pr�ximas 
## a los puntos donde se encuentran la estaci�n meteorol�gica 5972X de Aemet 
## (se�alado con un marcador) y la estaci�n Froggit (no aparece se�alado en el mapa 
## -por motivos de privacidad - pero est� dentro del cuadro calculado para las elevaciones).

# Incluimos las bibliotecas necesarias
library(scales) # M�todos Escalado de Mapas
library(elevatr) # Datos de Elevaci�n del Terreno
library(raster) # Manejo datos geospaciales 
library(leaflet) # Gesti�n Mapa Interactivo Leaflet
library(rgdal) # Gesti�n Biblioteca Abstracci�n Geospacial de Datos (GDAL)
library(prettyunits) # Formateado de unidades
library(png) # Gesti�n imagenes formato png

# Definimos las coordenadas de la estaci�on 5972X de Aemet
lat=36.4653517
lon=-6.2051278

# Descargamos los datos de elevaci�n (desde Amazon Web Services) y los asociamos a datos
# geospaciales mediante CRS
prj_dd <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
elev<-get_elev_raster(data.frame(x=lon,y=lat),z = 13,prj = prj_dd,src = 'aws')
crs(elev) <- CRS(prj_dd)

# Calculamos la pendiente del terreno en cada punto
slope=terrain(elev,opt='slope',unit = 'degrees')

# Definimos los esquemas de colores para la elevaci�n y para la pendiete
pal_elev <- colorNumeric(c("#132966", "#87c441", "#fa3939"), values(elev),
                         na.color = "transparent")
pal_slope <- colorNumeric('RdPu', values(slope),
                          na.color = "transparent")

# Dibujamos el mapa
leaflet() %>% 
  addProviderTiles(providers$Esri.WorldImagery,group='Esri.WorldImagery') %>%
  addProviderTiles(providers$Esri.WorldTopoMap,group='Esri.WorldTopoMap') %>%
  addProviderTiles(providers$Esri.WorldShadedRelief,group='Esri.WorldShadedRelief') %>%
  addRasterImage(elev, colors = pal_elev, opacity = 0.8,group='elevation') %>%
  addRasterImage(slope, colors = pal_slope, opacity = 0.8,group='slope') %>%
  addMarkers(lon,lat,popup='Turbine Location') %>%
  addLegend(pal = pal_elev, values = values(elev),title = "Elevation",position='topright') %>%
  addLegend(pal = pal_slope, values = values(slope),title = "Slope",position='bottomright') %>%
  addLayersControl(
    baseGroups = c("Esri.WorldTopoMap", "Esri.WorldImagery","Esri.WorldShadedRelief"),
    overlayGroups = c("elevation", "slope"),
    options = layersControlOptions(collapsed = FALSE),
    position = 'topleft') %>% 
  hideGroup("slope")