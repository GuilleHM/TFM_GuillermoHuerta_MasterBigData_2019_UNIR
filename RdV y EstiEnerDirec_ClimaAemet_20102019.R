# "Script" para la creación de la Rosa de los Vientos (RdV) y la determinación de
# de la energía que generaría un modelo concreto de turbina eólica para cada
# dirección del viento, según los datos aportados por la estación meteorológica de
# la aemet con indicativo 5972X (SAN FERNANDO, Cádiz)



# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\Desktop")

# Incluimos las librerías necesarias para la crear la RdV e importar archivos json
library(clifro)
library(rjson)

# Importamos los registros (para todos los días desde 01/01/2010 hasta 30/04/2019)
# desde un archivo csv (exportado desde mongodb) a una tabla y eliminamos los valores NA.
# Reseñar la eliminación de los valores erróneos 88 y 99 que provienen de los registros
wind_df <- read.csv(file = "mongoexport_VelyDir_ClimaAemet.csv", header = TRUE, sep = ",", dec = ".", col.names = c("Vel_MperS", "Dir_º"), na.strings = c(99, 88))
wind_df <- na.omit(wind_df) # Se eliminan aprox. el 7,3% de los registros



# Tenemos que multiplicar por 10 el campo "Dir" ya que desde aemet proporcionan los 
# datos como multiplos de 10º
wind_df$Dir_º <- wind_df$Dir_º * 10

# Creamos la RdV
with(wind_df, windrose(Vel_MperS, Dir_º, speed_cuts = c(3, 6, 9, 12,15),legend_title = "   5972X 2010 -2019 \nVelocidad Viento (m/s)"))

# Creamos un histograma con contenedores de datos cada 10º
with(wind_df, hist(Dir_º, breaks = 36, main = "Frec / Dir Viento Estación 5972X 
(2010 - 2019)", xlab = "Dirección Viento (º)", ylab = "Frecuencia (Total Obs: 3129)",
col = "red", border = "blue", freq = TRUE))

# Creamos un histograma para la distribución velocidades (intervalos de 0,25 m/s)
with(wind_df, hist(Vel_MperS, breaks = 48, main = "Frec / Vel Viento Estación 5972X 
(2010 - 2019)", xlab = "Dirección Viento (º)", ylab = "Frecuencia (Total Obs: 3129)",
col = "blue", border = "yellow", freq = TRUE))

# Contamos cuantos registros vienen desde el "sector libre" (aquel para el que no 
# existe ningún obstaculo en, al menos 100m) para el punto en el que se instalaría el aerogenerador
VientoDsdSectLibre <- cumsum(table(cut(wind_df$Dir_º, breaks = seq.int(from = 100, to = 300, by = 1))))
# El resultado indica un total de 2263 registros. Es decir el 72,32% del tiempo el
# viento sopla desde las direcciones óptimas (100 a 300º) para la localización del 
# aerogenerador(AG), ya que no hay un obstaculo en, al menos 100m, lo que garantiza un
# flujo laminar y, por ende, un a mayor extracción de potencia del AG.

# ---------------- A partir de aquí, determinamos la energía generada --------------------------

# Importamos la curva de potencia para un modelo de turbina
power_json <- fromJSON(file = "mongoexport_GENERADOR_i2000_48V.json")

# Pasamos los datos a una tabla
power_df <- as.data.frame(power_json)

# Eliminamos el campo _id (X.oid), exportado automáticamente desde mongodb
power_df$X.oid <- NULL

# Creamos dos listas, para la velocidad y la potencia que aparecen en la curva
vel_list <- pow_list <- list()

# Metemos en la lista de velocidades, los valores que aparecen codificados en los
# nombre de cada una de las columnas de la tabla
for (i in 1:ncol(power_df)){
  vel_list <- c(vel_list,as.integer(gsub("POWERCURVE.","", colnames(power_df)[i])))
}

# Añadimos una fila con los valores de velocidad
power_df <- rbind(power_df, vel_list)

# Metemos en la lista de potencias los valores que aparecen en la tabla
for (i in 1:ncol(power_df)){
  pow_list <- c(pow_list,power_df[1,i])
}

## Dibujamos la curva de potencia para el modelo de turbina seleccionado
## plot(vel_list,pow_list, type="l", xlab= "Vel(m/s)", ylab= "Power(W)", main= "Curva de Potencia / Modelo i-2000 48V")

# Columna a añadir a la tabla "wind_df" con la energía generada (en Wh)
Ene_Wh <- list()

# Metemos la energía que genereraría cada registro en Ene_Wh
for (i in 1:nrow(wind_df)){
  wind_MperS <- wind_df$Vel_MperS[i]
  energia <- 0
  
  # Buscamos entre qué dos valores de la curva de potencia se encuentra la velocidad
  # e interpolamos para obterner el valor de potencia media correpondiente a ese día
  # Luego multiplicamos por 24 para tener la energía en W/h
  for(j in 1:ncol(power_df)){
    if (power_df[2,j] >= wind_MperS && wind_MperS != 0){
      ene_temp <- approx(c(power_df[2,(j-1)], power_df[2,j]), c(power_df[1,(j-1)], power_df[1,j]), wind_MperS)
      energia <- round ((ene_temp$y * 24),0)  # Ya que son registros diarios 
      energia <- as.integer(energia)
      break
    }
  }
  Ene_Wh <- c(Ene_Wh, energia)
}

# Añadimos la columna de energía a la tabla wind_df
wind_df$Ene_Wh <- Ene_Wh
wind_df$Ene_Wh <- as.integer(wind_df$Ene_Wh) # Necesario para que aggregate funcione

# Creamos una nueva tabla con la energía según la dirección del viento
Energia_Dir <- aggregate(wind_df$Ene_Wh, list(wind_df$Dir_º), sum)
colnames(Energia_Dir) <- c("Direccion_º", "Energia_kWh")
Energia_Dir$Energia_kWh <- Energia_Dir$Energia_kWh / 1000 # Para pasar a kWh

# Obtenemos la energía total y la media anual
Suma_Energia_kWh <- sum(Energia_Dir$Energia_kWh)
MediaAnual_Energia_Kwh <- Suma_Energia_kWh / 3159 * 365
# 3159: dias desde 1 Enero 2010 hasta  30 Abril 2019, disminuido el 7,93% de los 
# registros eliminados (valores erróneos 88, 99 y valores na) y teniendo en cuenta
# los dos años bisisestos (2012 y 2016)

# Dibujamos la curva de energía generada en función de la dirección del viento
with(Energia_Dir, plot(Direccion_º,Energia_kWh, type="l", xlab= "Dirección viento (º)", ylab= "Energía Generada (kWh) - Media Anual: 770,66", 
main= "Energía teórica que hubiese generado una turbina i-2000 en
la localización de la estación 5972X (2010 - 2019)"))

# Hay que tener en cuenta que el valor de media anual:
# - No tiene en cuenta las las pérdidas en el circuito hasta las cargas 
# (conversor, cableado, etc.)
# - Supone una disponibilidad de la turbina del 100% (todos los días del año)
# - Supone una curva de potencia "real" para la turbina
# - Supone una localización al menos 10 m por encima de cualquier obstaculo
# a 100 metros a la redonda (perfil laminar viento)

## remove(i, j, energia, wind_MperS, ene_temp, Ene_Wh, Energia_Dir,Suma_Energia_kWh)
## remove(vel_list,pow_list)
## rm(list=ls())
