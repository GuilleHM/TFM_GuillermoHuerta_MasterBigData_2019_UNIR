# Este "script" sirve para complementar el archivo csv exportado desde la
# colecci�n "meteorologicos" de la BBDD "aemet" de nuestro servidor mongodb.
# En esta colecci�n se encuentran los valores meteorologicos horarios, obtenidos
# mediante llamada a la API OpenData de Aemet, para todas las estaciones meteorol�gicas
# que forman parte de la red de la Agencia Estatal de Meteorolog�a.
# Es necesario complementar el archivo csv que exportamos desde mongodb ya que faltan
# algunos registros temporales y es necesario que est�n todos para poder realizar
# la correlaci�n de dichos valores con los ofrecidos por la estaci�n FROGGIT, para
# as� garantizar la bondad de las medidas de �sta �ltima.
# Utilizamos los valores de la estaci�n con "idema":"5972X" (SAN FERNANDO), ya que
# es la que se ecuentra m�s pr�xima a la estaci�n FROGGIT. No obstante, podr�amos
# emplear los registros de cualquier estaci�n en este "script".
# NOTA IMPORTANTE: El archivo tiene que estar codificado en formato ANSI


# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\TFM\\OpendataAEMET")


# Cargamos el paquete que necesitaremos para manipular las fechas
library(lubridate)


# Cargamos los datos provenientes de la colecci�n
aemetorigin <- read.csv(file = "mongoexport_meteoro_5972X_VvFint_may19.csv", header = TRUE, sep = ",", dec = ".")


# Definimos e inicializamos las variables con las que trabajaremos
# ----------------------------------------------------------------

# Obtenemos la fecha de inicio (los valores en el csv son para cada mes)
A�o <- substring(as.character(aemetorigin$fint[1]),1,4)
Mes <- substring(as.character(aemetorigin$fint[1]),6,7)
D�a <- substring(as.character(aemetorigin$fint[1]),9,10)

# Valor que servir� para comprobar si falta un registro
FechaControl <- ISOdate(A�o,Mes,D�a,00,00,00, tz="GMT")

# Formateamos para poder comparar con FechaControl
FechaOriginal <- ymd_hms(aemetorigin$fint, tz ="GMT")

# Creamos la tabla final sobre la que realizaremos el an�lisis
# Damos a las columnas los mismos valores que los de la tabla final para los
# valores de la estaci�n meteorol�gica Froggit.
aemetfinal <- data.frame(FechaFinal = FechaOriginal[1], VelFinal = aemetorigin$vv[1])

# n -> Cuenta los registros horarios no existentes en el archivo original de aemet
# m -> Puntero para movernos por la tabla aemet final 
# longitud -> N�mero de campos existentes en el archivo original de aemet
n <- m <- 0
longitud <- length(FechaOriginal)

# ----------------------------------------------------------------


# Recorremos la tabla original e incluimos en la tabla final los registros temporales
# que falten, con un valor NA para la velocidad del viento
for (i in 1:longitud){
  if (i == 1) {
    FechaControl <- FechaControl + hours(1)
    next
  }
  if (FechaControl != FechaOriginal[i-n]){
    n <- n + 1
    aemetfinal <- rbind(aemetfinal, list(FechaControl, NA))
  }
  else{
    aemetfinal <- rbind(aemetfinal, list(FechaControl, aemetorigin$vv[i-n]))
  }
  FechaControl <- FechaControl + hours(1)
}

# Actualizamos m con la posici�n desde donde continuar insertando campos
m <- longitud - n + 1

# Repetimos las inserciones hasta que no quede ning�n registro sin incorporar
# a la tabla final de valores de aemet
while (n != 0) {
  
  temp <- n
  for (i in 1:n){
    if (i == 1) {
      n <- 0
    }
    if (FechaControl != FechaOriginal[m]){
      aemetfinal <- rbind(aemetfinal, list(FechaControl, NA))
      n <- n + 1
    }
    else{
      aemetfinal <- rbind(aemetfinal, list(FechaControl, aemetorigin$vv[m]))
      m <- m + 1
    }
    FechaControl <- FechaControl + hours(1)
  }
  longitud <- longitud + temp
}

# Guardamos los valores en el archivo que emplearemos para los an�lisis
write.csv(aemetfinal, file = "SalidaScriptValoresHorariosCompletosAemetMay.csv", row.names = FALSE)

# Limpiamos el entorno borrando todas las variables
rm(list=ls())
