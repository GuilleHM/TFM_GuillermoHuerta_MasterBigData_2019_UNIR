## Este "script" nos sirve para calcular la densidad media mensual del aire (desde los datos de
## presi�n, temperatura y humedad relativa) para cada uno de los meses del a�o en la localizaci�n
## de la estaci�n meteorol�gica FROGGIT.
## Para ello utiliza los datos obtenidos desde la web www.theweatherunderground.com para una
## estaci�n meteorologica cercana (IANDALUCIA70) en el periodo Ene 2015 - Jun 2019 (ya que la API Opendata
## de la Aemet, no ofrece datos climatol�gicos de humedad relativa).
## Para validar los datos recogidos por dicha estaci�n, correlacionamos los datos diarios para
## los meses de Mayo y Junio de 2019, con los ofrecidos por AEMET OpenData (que s� que ofrece los valores
## medios horarios de humedad relativa para las �ltimas 24 horas y que estamos recogiendo desde
## Mayo de 2019 en la colecci�n "meteorologicos" de la BBDD "aemet" en nuestro depliegue local de mongodb)
## Emplearemos esta densidad del arie para calcular la densidad de potencia por m2 en la localizaci�n
## de la estaci�n Froggit en un "script" separado.

## ---------------------------------------------------------------------------- ##

# Cargamos las bibliotecas que nos har�n falta
library(tidyverse) # Ecosistema Paquetes-r  
library(lubridate) # Formateado de fechas

# Selecionamos el tema o formato general para las visualizaciones
theme_set(theme_minimal())

# Configuramos el directorio de trabajo donde colocaremos el archivo con los datos de 
# Temperatura (C), Presi�n (mbar) y Humedad Relativa (%)
setwd("C:\\Users\\GuilleHM\\Desktop")

## ------------------------------------------------------------------------- ##

## Correlaci�n y c�lculo de las rectas de regresi�n para la T, P y HR (comparando los valores
## de la estaci�n IANDA a la 5972X de la Aemet para los meses de Mayo y Junio de 2019)

# Creamos una tabla con los datos de la estaci�n IANDALUCIA70 (cercana a la estaci�n FROGGIT) desde
# Enero de 2015 hasta Junio de 2019
iandalu_data = read_csv('IANDALUC70_Ene2015Jun2019_Ele7Lat36o45_Lon6o22_Reducido.csv',col_types=cols(), col_names = TRUE)
# Cambiamos el nombre de las columnas
colnames(iandalu_data) <- c("Fecha", "P", "RH", "Temp")
# Damos formato estandar de fecha
iandalu_data$Fecha <- mdy(iandalu_data$Fecha)

# Creamos una tabla reducida con los datos de Mayo y Junio de 2019
iandalu_red <- tail(iandalu_data, 61)

# Creamos una tabla con los valores de P,T y HR de Aemet para la estaci�n
# 5972X en los meses de Mayo y Junio de 2019. 
aemet_data = read_csv('mongoexport_aemet_meteoro_fint_ta_pres_hr_5972X_MayJun19.csv',col_types=cols(), col_names = TRUE)
# Cambiamos el nombre de las columnas
colnames(aemet_data) <- c("Fecha", "Temp", "P", "RH")

# Creamos una tabla con los datos resumidos en valores diarios (los datos de la tabla aemet_data son horarios)
aemet_means<-aemet_data %>%
  mutate(Fecha=date(Fecha)) %>%
  group_by(Fecha) %>%
  summarise(T_MediaDia=mean(Temp,na.rm=T), P_MediaDia=mean(P,na.rm=T),
            RH_MediaDia=mean(RH,na.rm=T))

# Creamos una tabla conjunta 
aemet_iandalu <- left_join(aemet_means, iandalu_red, by= "Fecha")

# Correlacionamos los tres par�metros
cor(aemet_iandalu$T_MediaDia, aemet_iandalu$Temp, use =  "complete.obs")
cor(aemet_iandalu$P_MediaDia, aemet_iandalu$P, use =  "complete.obs")
cor(aemet_iandalu$RH_MediaDia, aemet_iandalu$RH, use =  "complete.obs")

# Calculamos los coeficientes de las respectivas rectas de regresi�n
RegLineT <- lm(aemet_iandalu$Temp ~ aemet_iandalu$T_MediaDia, aemet_iandalu)
RegLineT # Coeficientes de la recta: a = 1.65, b = 0.87
RegLineP <- lm(aemet_iandalu$P ~ aemet_iandalu$P_MediaDia, aemet_iandalu)
RegLineP # Coeficientes de la recta: a = 42.32, b = 0.96
RegLineRH <- lm(aemet_iandalu$RH ~ aemet_iandalu$RH_MediaDia, aemet_iandalu)
RegLineRH # Coeficientes de la recta: a = -0.66, b = 1.06

# Dibujamos un gr�fico con las tres rectas
par(mfrow=c(1,3), title)
plot(aemet_iandalu$T_MediaDia, aemet_iandalu$Temp, main= "Regresion Temperatura, Presi�n y HR\n\n",
     xlab="Temperatura Estaci�n 5972X Aemet (�C)", ylab="Temperatura Estaci�n IANDA (�C)",
     pch=20, col = 'red')
mtext("Y = 1.65 + 0.87X", side=3)
abline(RegLineT, col = 'red')
plot(aemet_iandalu$P_MediaDia, aemet_iandalu$P,
     xlab="Presi�n Estaci�n 5972X Aemet (mbar)", ylab="Presi�n Estaci�n IANDA (mbar)",
     pch=20, col = 'blue')
mtext("Y = 42.32 + 0.96X", side=3)
abline(RegLineP, col = 'blue')
plot(aemet_iandalu$RH_MediaDia, aemet_iandalu$RH,
     xlab="Humedad Relativa Estaci�n 5972X Aemet (�C)", ylab="Humedad Relativa Estaci�n IANDA (%)",
     pch=20, col = 'green')
mtext("Y = -0.66 + 1.06X", side=3)
abline(RegLineRH, col = 'green')

## ------------------------------------------------------------------------- ##

## C�lculo de la densidad media mensual del aire para cada uno de los meses del a�o en 
## la localizaci�n de la estaci�n meteorol�gica FROGGIT.

# Aplicamos los respectivos coeficientes de regresi�n
iandalu_data$P <- round(42.32 + iandalu_data$P*0.96, 2)
iandalu_data$Temp <- round(1.65 + iandalu_data$Temp*0.87, 2)
iandalu_data$RH <- round(-0.66 + iandalu_data$RH*1.06, 2)

# Agrupamos los valores por meses y calculamos la media mensual
iandalu_means<-iandalu_data %>%
  mutate(mes=month(Fecha), diasenelmes=days_in_month(Fecha)) %>%
  dplyr::select(-Fecha) %>%
  group_by(mes) %>%
  summarise(T_MediaMes=mean(Temp,na.rm=T), P_MediaMes=mean(P,na.rm=T),
            RH_MediaMes=mean(RH,na.rm=T), diasenelmes=mean(diasenelmes))

# Constante Gases para el aire seco (J/Kg*K)
Rd <- 287.058
# Constante Gases para el vapor de agua (J/Kg*K)
Rv <- 461.495
# Temperatura en grados Kelvin (K)
iandalu_means$TempK <- iandalu_means$T_MediaMes + 273.15
# Presi�n de saturaci�n del vapor de agua (hPa)
iandalu_means$psat_h2o <- 6.102 * 10^(7.5*iandalu_means$T_MediaMes/(iandalu_means$T_MediaMes+237.8)) 
# Presi�n parcial del vapor de agua (Pa)
iandalu_means$pp_h2o <- iandalu_means$psat_h2o * iandalu_means$RH_MediaMes
# Presi�n parcial del aire seco
iandalu_means$pp_aireseco <- 100*iandalu_means$P_MediaMes - iandalu_means$pp_h2o
# Densidad del aire
iandalu_means$densidadaire <- (iandalu_means$pp_aireseco/(Rd*iandalu_means$TempK)) + (iandalu_means$pp_h2o/(Rv*iandalu_means$TempK))

## --------------------------------------------------------------------------------- ##

# Eliminamos las variables del entorno 
rm(list=ls())

