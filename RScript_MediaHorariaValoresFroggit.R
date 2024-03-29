# Este "script" sirve para sacar el promedio horario de los valores de la
# estaci�n meteorol�gica, obtenidos en formato csv desde la web a la que
# est� ligada la misma (www.weatherCloud.com).
# En el archivo recibimos los valores para los par�metros que registra
# la estaci�n, con una fecuencia de 10 minutos. Existen columnas completas
# con valores NA o "Not Available" (ya que ese par�metro no es ofrecido por la estaci�n), 
# faltan algunas filas (no aparece ese registro temporal) y, en determinadas
# filas, el valor para algunos de los par�metros que s� que recoge la
# estaci�n, aparece como NA. Por ello, es necesaria la limpieza y preparaci�n
# de un archivo con el que poder trabajar posteriormente en la fase de an�lisis.
# NOTA IMPORTANTE: El archivo tiene que estar codificado en formato ANSI


# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\TFM\\FROGGIT")

# Cargamos los paquetes que necesitaremos para manipular las fechas y valores NA
library(dplyr)
library(lubridate)


# Guardamos los valores del archivo csv en una tabla o "data frame".
Froggit <- read.csv(file = "WeathercloudLomasdeCamposotoMay.csv", header = TRUE, sep = ",", dec = ".")


# Creamos una funci�n que necesitamos para limpiar los valores NA
not_all_na <- function(x) any(!is.na(x))


# Lipiamos la tabla de las columnas con todos su valores NA
Froggit <- Froggit %>% select_if(not_all_na)


# Definimos e inicializamos las variables con las que trabajaremos
# ----------------------------------------------------------------

# Obtenemos la fecha de inicio (los valores en el csv son para cada mes)
A�o <- substring(as.character(Froggit$Fecha[1]),1,4)
Mes <- substring(as.character(Froggit$Fecha[1]),6,7)
D�a <- substring(as.character(Froggit$Fecha[1]),9,10)

# Valor que servir� para comprobar si falta un registro
FechaControl <- ISOdate(A�o,Mes,D�a,00,10,00, tz="GMT")

# Formateamos para poder comparar con FechaControl
FechaOriginal <- ymd_hms(Froggit$Fecha, tz ="GMT")

# Creamos el valor inicial de la fecha para la tabla con los valores horarios
FechaPromedioHorario <- ISOdate(A�o,Mes,D�a,00,00,00,tz="GMT")

# Creamos una tabla intermedia con las columnas con los que nos interesa trabajar
TablaMedia <- data.frame(FechaMedia = FechaControl, VelMedia = Froggit$Wspdavg..m.s.[1])

# Creamos la tabla final sobre la que realizaremos el an�lisis
TablaFinal <- data.frame(FechaFinal = FechaPromedioHorario, VelFinal = 0.0)

# contador -> n�mero de elementos sobre los que hacer la media para cada registro 
# horario (en nuestro caso, 6: 00,10,20,30,40 y 50 min)
# n -> n�mero de registros temporales que faltan ("missing") en la tabla original
# m -> actualizaci�n de n para llegar a iterar sobre todos los registros temporales 
# de la tabala original
# ciclos -> n�mero de registros temporales medios horarios a�adidos a la tabla final
# longitud -> n�mero total de registros de la tabla original
# puntero -> nos sirve para recorrer la tabla final junto con ciclos
contador <- n <- m <- 0  
ciclos <- 1
longitud <- length(FechaOriginal)
puntero <- 6

# ----------------------------------------------------------------


# A�adimos a la tabla intermedia la velocidad del viento para cada registro temporal
# (si no existe el registro temporal, lo a�adimos con valor NA para la velocidad del viento)
for (i in 1:longitud){
  if (i == 1) {
    FechaControl <- FechaControl + minutes(10)
    next
  }
  if (FechaControl != FechaOriginal[i-n]){
    n <- n + 1
    TablaMedia <- rbind(TablaMedia, list(TablaMedia$FechaMedia[[i-1]] + minutes(10), 0.0))
  }
  else{
    TablaMedia <- rbind(TablaMedia, list(TablaMedia$FechaMedia[[i-1]] + minutes(10), Froggit$Wspdavg..m.s.[i-n]))
  }
  FechaControl <- FechaControl + minutes(10)
}


# Actualizamos m con los registros que faltan por a�adir a la tabla media
m <- longitud - n + 1


# Mientras que falten registros temporales, seguimos iterando sobre la tabla original
# para obterner una tabla intermedia que incluya todos los registros temporales de la
# tabla original, as� como los que faltaban
while (n != 0) {
  temp <- n
  for (i in 1:n){
    if (i == 1) {
      n <- 0
    }
    if (FechaControl != FechaOriginal[m]){
      TablaMedia <- rbind(TablaMedia, list(TablaMedia$FechaMedia[[longitud+i-1]] + minutes(10), 0.0))
      n <- n + 1
    }
    else{
      TablaMedia <- rbind(TablaMedia, list(TablaMedia$FechaMedia[[longitud+i-1]] + minutes(10), Froggit$Wspdavg..m.s.[m]))
      m <- m + 1
    }
    FechaControl <- FechaControl + minutes(10)
  }
  longitud <- longitud + temp
}


# Promediamos cada 6 registros y creamos un registros temporal horario con esa media
# que incluimos en la tabla final
for (j in 1:nrow(TablaMedia)){
  contador <- contador + 1
  if ((contador %% 5) == 0){
    if (ciclos == 1){
      TablaFinal$VelFinal[[ciclos]] <- mean(TablaMedia$VelMedia[1:5],na.rm = TRUE)
    }
    else{
      TablaFinal <- rbind(TablaFinal, list(TablaFinal$FechaFinal[[ciclos - 1]] + hours(1), round(mean(TablaMedia$VelMedia[puntero:(puntero+5)],na.rm = TRUE),2)))
      puntero <- puntero + 6
    }
    ciclos <- ciclos + 1
  }
  if (ciclos > nrow(TablaMedia) %/% 6){ # Para el caso final: es posible que no haya 6 registros
    cola <- (nrow(TablaMedia) %% 6) + 1
    TablaFinal <- rbind(TablaFinal, list(TablaFinal$FechaFinal[[ciclos - 1]] + hours(1), round(mean(tail(TablaMedia$VelMedia, cola),na.rm = TRUE),2)))
    break
  }
}

# Guardamos los valores en el archivo que emplearemos para los an�lisis
write.csv(TablaFinal, file = "SalidaScriptRPromedioHorarioMay.csv", row.names = FALSE)

# Limpiamos el entorno borrando todas las variables
rm(list=ls())
