# "Script" para la creaci�n de la Rosa de los Vientos (RdV) y la determinaci�n de
# de la energ�a que generar�a un modelo concreto de turbina e�lica para cada
# direcci�n del viento, seg�n los datos aportados por la estaci�n meteorol�gica de
# la aemet con indicativo 5972X (SAN FERNANDO, C�diz)



# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\Desktop")

# Incluimos las librer�as necesarias para la crear la RdV e importar archivos json
library(clifro)
library(rjson)

# Importamos los registros (para todos los d�as desde 01/01/2010 hasta 30/04/2019)
# desde un archivo csv (exportado desde mongodb) a una tabla y eliminamos los valores NA.
# Rese�ar la eliminaci�n de los valores err�neos 88 y 99 que provienen de los registros
wind_df <- read.csv(file = "mongoexport_VelyDir_ClimaAemet.csv", header = TRUE, sep = ",", dec = ".", col.names = c("Vel_MperS", "Dir_�"), na.strings = c(99, 88))
wind_df <- na.omit(wind_df) # Se eliminan aprox. el 7,3% de los registros



# Tenemos que multiplicar por 10 el campo "Dir" ya que desde aemet proporcionan los 
# datos como multiplos de 10�
wind_df$Dir_� <- wind_df$Dir_� * 10

# Creamos la RdV
with(wind_df, windrose(Vel_MperS, Dir_�, speed_cuts = c(3, 6, 9, 12,15),legend_title = "   5972X 2010 -2019 \nVelocidad Viento (m/s)"))

# Creamos un histograma con contenedores de datos cada 10�
with(wind_df, hist(Dir_�, breaks = 36, main = "Frec / Dir Viento Estaci�n 5972X 
(2010 - 2019)", xlab = "Direcci�n Viento (�)", ylab = "Frecuencia (Total Obs: 3129)",
col = "red", border = "blue", freq = TRUE))

# Creamos un histograma para la distribuci�n velocidades (intervalos de 0,25 m/s)
with(wind_df, hist(Vel_MperS, breaks = 48, main = "Frec / Vel Viento Estaci�n 5972X 
(2010 - 2019)", xlab = "Direcci�n Viento (�)", ylab = "Frecuencia (Total Obs: 3129)",
col = "blue", border = "yellow", freq = TRUE))

# Contamos cuantos registros vienen desde el "sector libre" (aquel para el que no 
# existe ning�n obstaculo en, al menos 100m) para el punto en el que se instalar�a el aerogenerador
VientoDsdSectLibre <- cumsum(table(cut(wind_df$Dir_�, breaks = seq.int(from = 100, to = 300, by = 1))))
# El resultado indica un total de 2263 registros. Es decir el 72,32% del tiempo el
# viento sopla desde las direcciones �ptimas (100 a 300�) para la localizaci�n del 
# aerogenerador(AG), ya que no hay un obstaculo en, al menos 100m, lo que garantiza un
# flujo laminar y, por ende, un a mayor extracci�n de potencia del AG.

# ---------------- A partir de aqu�, determinamos la energ�a generada --------------------------

# Importamos la curva de potencia para un modelo de turbina
power_json <- fromJSON(file = "mongoexport_GENERADOR_i2000_48V.json")

# Pasamos los datos a una tabla
power_df <- as.data.frame(power_json)

# Eliminamos el campo _id (X.oid), exportado autom�ticamente desde mongodb
power_df$X.oid <- NULL

# Creamos dos listas, para la velocidad y la potencia que aparecen en la curva
vel_list <- pow_list <- list()

# Metemos en la lista de velocidades, los valores que aparecen codificados en los
# nombre de cada una de las columnas de la tabla
for (i in 1:ncol(power_df)){
  vel_list <- c(vel_list,as.integer(gsub("POWERCURVE.","", colnames(power_df)[i])))
}

# A�adimos una fila con los valores de velocidad
power_df <- rbind(power_df, vel_list)

# Metemos en la lista de potencias los valores que aparecen en la tabla
for (i in 1:ncol(power_df)){
  pow_list <- c(pow_list,power_df[1,i])
}

## Dibujamos la curva de potencia para el modelo de turbina seleccionado
## plot(vel_list,pow_list, type="l", xlab= "Vel(m/s)", ylab= "Power(W)", main= "Curva de Potencia / Modelo i-2000 48V")

# Columna a a�adir a la tabla "wind_df" con la energ�a generada (en Wh)
Ene_Wh <- list()

# Metemos la energ�a que genererar�a cada registro en Ene_Wh
for (i in 1:nrow(wind_df)){
  wind_MperS <- wind_df$Vel_MperS[i]
  energia <- 0
  
  # Buscamos entre qu� dos valores de la curva de potencia se encuentra la velocidad
  # e interpolamos para obterner el valor de potencia media correpondiente a ese d�a
  # Luego multiplicamos por 24 para tener la energ�a en W/h
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

# A�adimos la columna de energ�a a la tabla wind_df
wind_df$Ene_Wh <- Ene_Wh
wind_df$Ene_Wh <- as.integer(wind_df$Ene_Wh) # Necesario para que aggregate funcione

# Creamos una nueva tabla con la energ�a seg�n la direcci�n del viento
Energia_Dir <- aggregate(wind_df$Ene_Wh, list(wind_df$Dir_�), sum)
colnames(Energia_Dir) <- c("Direccion_�", "Energia_kWh")
Energia_Dir$Energia_kWh <- Energia_Dir$Energia_kWh / 1000 # Para pasar a kWh

# Obtenemos la energ�a total y la media anual
Suma_Energia_kWh <- sum(Energia_Dir$Energia_kWh)
MediaAnual_Energia_Kwh <- Suma_Energia_kWh / 3159 * 365
# 3159: dias desde 1 Enero 2010 hasta  30 Abril 2019, disminuido el 7,93% de los 
# registros eliminados (valores err�neos 88, 99 y valores na) y teniendo en cuenta
# los dos a�os bisisestos (2012 y 2016)

# Dibujamos la curva de energ�a generada en funci�n de la direcci�n del viento
with(Energia_Dir, plot(Direccion_�,Energia_kWh, type="l", xlab= "Direcci�n viento (�)", ylab= "Energ�a Generada (kWh) - Media Anual: 770,66", 
main= "Energ�a te�rica que hubiese generado una turbina i-2000 en
la localizaci�n de la estaci�n 5972X (2010 - 2019)"))

# Hay que tener en cuenta que el valor de media anual:
# - No tiene en cuenta las las p�rdidas en el circuito hasta las cargas 
# (conversor, cableado, etc.)
# - Supone una disponibilidad de la turbina del 100% (todos los d�as del a�o)
# - Supone una curva de potencia "real" para la turbina
# - Supone una localizaci�n al menos 10 m por encima de cualquier obstaculo
# a 100 metros a la redonda (perfil laminar viento)

## remove(i, j, energia, wind_MperS, ene_temp, Ene_Wh, Energia_Dir,Suma_Energia_kWh)
## remove(vel_list,pow_list)
## rm(list=ls())
