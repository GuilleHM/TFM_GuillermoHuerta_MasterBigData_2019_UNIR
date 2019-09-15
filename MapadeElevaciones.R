## Este "script" nos permite obtener un mapa con las elevaciones y las pendientes próximas 
## a los puntos donde se encuentran la estación meteorológica 5972X de Aemet 
## (señalado con un marcador) y la estación Froggit (no aparece señalado en el mapa 
## -por motivos de privacidad - pero está dentro del cuadro calculado para las elevaciones).

# Incluimos las bibliotecas necesarias
library(scales) # Métodos Escalado de Mapas
library(elevatr) # Datos de Elevación del Terreno
library(raster) # Manejo datos geospaciales 
library(leaflet) # Gestión Mapa Interactivo Leaflet
library(rgdal) # Gestión Biblioteca Abstracción Geospacial de Datos (GDAL)
library(prettyunits) # Formateado de unidades
library(png) # Gestión imagenes formato png

# Definimos las coordenadas de la estaciçon 5972X de Aemet
lat=36.4653517
lon=-6.2051278

# Descargamos los datos de elevación (desde Amazon Web Services) y los asociamos a datos
# geospaciales mediante CRS
prj_dd <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
elev<-get_elev_raster(data.frame(x=lon,y=lat),z = 13,prj = prj_dd,src = 'aws')
crs(elev) <- CRS(prj_dd)

# Calculamos la pendiente del terreno en cada punto
slope=terrain(elev,opt='slope',unit = 'degrees')

# Definimos los esquemas de colores para la elevación y para la pendiete
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