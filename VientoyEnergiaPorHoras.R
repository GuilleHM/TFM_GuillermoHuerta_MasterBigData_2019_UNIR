## Este "script" sirve para calcular y crear un gráfico con la variación de la velocidad del 
## viento según la hora para cada mes del año.
## Para ello se emplearán los archivos .csv provinientes de la conversión de los archivos .grib
## descargados desde la BBDD ERA-Iterim de la ECMWF para el periodo 1979 - 2018. Estos archivos proporcionan
## medidas a las 00, 06, 12 y 18h, por lo que el resto de valores los obtendremos por interpolación lineal.
## Con los valores relativos del viento según la hora y el resto de parámetros necesarios (calculados en varios
## "scripts" complementarios a éste), calculamos la energía media por hora generada por cada una de las cuatro
## instalaciones de aerogeneradores que estamos contemplando: dos modelos (i-700 e i-1000) y dos alturas (0m,
## o cero metros sobre la altura de instalación de la estación meteorológica FROOGIT -10metros- y 10m, o
## 10 metros por encima de la altura de la estación FROGGIT).
## Para que el "script" funcione, debemos establecer como directorio de trabajo aquél en el que 
## se encuentran los archivos

# Cargamos las bibliotecas que nos harán falta
library(tidyverse) # Ecosistema Paquetes-r  
library(lubridate) # Formateado de fechas
library(MASS) # Funciones estadísticas
library(stringr) # Modificación de cadenas
library(zoo)
library(viridis)
library(broom)
library(plotly)
library(knitr) # Dibujo de tablas
library(ggplot2)
library(fitdistrplus)
library(devtools)
library(ggpubr)


# Establecemos el diretrio de trabajo 
setwd("C:\\Users\\GuilleHM\\TFM\\ERAInterim\\csv_files")

# Creamos un vector con el nombre de los meses
meses <- c("ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC")

# Creamos la tabla donde guardaremos las medias para cada franja horaria y cada mes
df_VVhoraria_Meses <- data.frame(Mes=meses, H0=rep(0,12), H6=rep(0,12), H12=rep(0,12), H18=rep(0,12))

# Iteramos para los doce meses del año
for (i in 1:12) {
  
  # Guardamos los nombres de los archivos para cada mes del año
  files <- list.files(path=".", pattern=paste0("*", sprintf("%02d", i), ".csv", sep=""), full.names=TRUE, recursive=FALSE)
  # Creamos un vector para cada franja horaria (correspondiente a cada mes)
  H00 <- H06 <- H12 <- H18 <- c()
  
  # Iteramos sobre todos los archivos (1 por año) para cada mes del año
  for (j in 1:length(files)) {
    
    # Creamos un vector para cada franja horaria (correspodiente a al mes del año en concreto sobre el que estmos iterando)  
    h00 <- h06 <- h12 <- h18 <- c()
    
    # Creamos una tabla temporal donde guardamos los valores del archivo correspondiente
    df_temp = read_csv(files[j], col_types=cols(), col_names = F)
    colnames(df_temp) <- c("VV_alternate_u_v_componets_m/s")
    
    # Nos aseguramos de que el archivo tiene el numero correcto de filas para no introducir cálculos erróneos
    filas <- nrow(df_temp)
    if (filas != 224 && filas != 232 && filas != 240 && filas != 248){next}
    
    # Iteramos sobre la tabla (correpondiente a un mes de un año concreto) y agrupamos 
    # los valores por franja horaria en el vector correspondiente
    columna <- 1
    for (z in seq(from=1, to=filas-1, by=2)){
      raiz_temp = sqrt((df_temp[[z,1]])^2 + (df_temp[[(z+1),1]])^2)
      if (raiz_temp >= 40){
        columna <- columna + 1
        if (columna == 5){columna <- 1}
        next
      }
      else{
        if (columna == 1){h00 <- c(h00, raiz_temp)}
        if (columna == 2){h06 <- c(h06, raiz_temp)}
        if (columna == 3){h12 <- c(h12, raiz_temp)}
        if (columna == 4){h18 <- c(h18, raiz_temp)}
      }
      columna <- columna + 1
      if (columna == 5){columna <- 1}
    }
    # Guardamos la media para cada franja horaria para el mes en el año concreto sobre el que estamos iterando
    H00 <- c(H00, mean(h00))
    H06 <- c(H06, mean(h06))
    H12 <- c(H12, mean(h12))
    H18 <- c(H18, mean(h18))
  }
  
  # Calculamos y guardamos en la tabla final la media para cada franja horaria para cada mes del año
  df_VVhoraria_Meses[i,2] <- round(mean(H00, na.rm = T),2)
  df_VVhoraria_Meses[i,3] <- round(mean(H06, na.rm = T),2)
  df_VVhoraria_Meses[i,4] <- round(mean(H12, na.rm = T),2)
  df_VVhoraria_Meses[i,5] <- round(mean(H18, na.rm = T),2)

}

# Guardamos la tabla con los valores medios para cada franja en cada mes en un archivo .csv
write.csv(df_VVhoraria_Meses, file = "VelocidadMediaVientoFranjaHoraria.csv", row.names = FALSE)

# Calculamos la media de cada mes
medias_mensuales <- rowMeans(df_VVhoraria_Meses[,-1])

# Calculamos y sustituimos el valor en la tabla por el porcentaje (en tantos por ciento) de velocidad 
# del viento sobre la media diaria, para cada franja horaria para cada mes del año
for (mes in 1:12) {
  for (hora in 2:5) {
    df_VVhoraria_Meses[mes, hora] <- (df_VVhoraria_Meses[mes, hora] / medias_mensuales[mes])*100
  }
}

# Interpolamos linearmente para obterner los valores horarios de  porcentaje de velocidad del viento

# Creamos primero la tabla
df_VVInterp_Meses <- data.frame(hora=c(0:23), Ene= rep(0,24), Feb= rep(0,24), Mar= rep(0,24), Abr= rep(0,24), May= rep(0,24), 
                                Jun= rep(0,24), Jul= rep(0,24), Ago= rep(0,24), Sep= rep(0,24), Oct= rep(0,24), Nov= rep(0,24), Dic= rep(0,24))

# Iteramos sobre la tabla, interpolando linealmente los valores de porcentaje del viento
for (mes in 1:12) {
  contador <- 1
  H <- 1
  for (hora in 1:24) {
    if ((hora-1) == 0 | (hora-1) == 6 | (hora-1) == 12 | (hora-1) == 18 ){
      df_VVInterp_Meses[hora, (mes+1)] <- df_VVhoraria_Meses[mes,(H+1)]
      H <- H + 1
    } else if ((hora-1) != 23){
      if (H==5){
        df_VVInterp_Meses[hora, (mes+1)] <- approx(c(0,6), c(df_VVhoraria_Meses[mes,5], df_VVhoraria_Meses[mes,(2)]), xout=contador)$y
      }
      else{
        df_VVInterp_Meses[hora, (mes+1)] <- approx(c(0,6), c(df_VVhoraria_Meses[mes,H], df_VVhoraria_Meses[mes,(H+1)]), xout=contador)$y
      }
      contador <- contador + 1
      if(contador==6){contador <- 1}
    }
    else{
      df_VVInterp_Meses[hora, (mes+1)] <- approx(c(0,6), c(df_VVhoraria_Meses[mes,5], df_VVhoraria_Meses[mes,(2)]), xout=contador)$y
      H <- 1
      contador <- 1
    }
  }
}

# Guardamos la tabla con los valores de velocidad del viento proporcionales a la media diaria ,
# para cada franja horaria para cada mes en un archivo .csv
write.csv(df_VVInterp_Meses, file = "VariacionVelocidadVientoFranjaHoraria.csv", row.names = FALSE)

# Eliminamos la columna con los nombres de los meses
df_VVhoraria_Meses$Mes <- NULL

# Trasponemos la tabla
df_VVhoraria_Meses <- t(df_VVhoraria_Meses)

# Dibujamos un gráfico de barras agrupadas (4 franjas horarias por grupo) para cada mes del año
barplot(df_VVhoraria_Meses, col=c("#de7878", "#ded778", "#78de8e", "#47427d"),
        main="Variación de la velocidad del viento según la franja horaria",
        xlab= "dd", ylab= "% sobre la media diaria en cada mes del año", ylim=c(80,130), 
        legend.text=c("00h","06h", "12h", "18h"), beside = T)


## -------- Calculamos la energía teórica para cada hora --------------- ##


# Creamos las tablas donde guardaremos los valores estimados de energía horaria generada para cada modelo (2)
# y altura (2). En total trabajaremos con cuatro opciones
df_energia_hora_i700_0 <- df_VVInterp_Meses / 100
colnames(df_energia_hora_i700_0) <- c("Hora", "WT_ENE", "WT_FEB", "WT_MAR", "WT_ABR", "WT_MAY", "WT_JUN", "WT_JUL", "WT_AGO", "WT_SEP", "WT_OCT", "WT_NOV", "WT_DIC")
df_energia_hora_i700_0$Hora <- df_energia_hora_i700_0$Hora * 100
df_energia_hora_i700_10 <- df_energia_hora_i1000_0 <- df_energia_hora_i1000_10 <- df_energia_hora_i700_0

## Creamos las variables que necesitaremos para hacer los cálculos de energía generada

# Densidad del aire media para cada mes del año
DensAire <- c(1.247, 1.241, 1.233, 1.221, 1.208, 1.199, 1.190, 1.185, 1.195, 1.204, 1.227, 1.242)
# Área efectiva para cada modelo
a_i700 <- 2.83
a_i1000 <- 3.98
# Coeficiente de potencia para cada modelo (eliminamos el Cp correspondiente a 0 m/s para casar los valores
# con los contenedores de 1m/s de la tabla para el cálculo de la energía). Rango 1-21 m/s Velocidad Viento.
cp_i700 <- c(0.000000,0.000000,0.000000,35.989501,34.714282,29.324779,29.377437,26.992126,25.474763,23.321197,
             20.875412,18.661223,16.773884,15.109295,13.137421,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000)
cp_i1000 <- c(0.000000,0.000000,0.000000,32.079530,37.956567,34.218165,29.926644,25.663624,22.531110,19.709663,
              17.431242,15.445699,14.951535,14.216001,13.383024,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000)
# Factores de escala y forma (para cada mes del año) para cada una de las localizaciones (altura 
# estación FROGGIT - 0m - y 10 metros por encima -10m-)
escala_0m <- c(3.04,	3.6, 4.18, 4.45, 4.48, 4.43,	4.08, 3.94,	3.71,	3.43,	3.11, 3.15)
escala_10m <- c(3.64,	4.32, 5.00, 5.32, 5.36, 5.30,	4.89, 4.71,	4.45,	4.1,	3.73, 3.77)
forma <- c(1.72, 1.89, 2.1, 2.43, 2.54, 2.66,	2.76,	2.55,	2.58,	2.15,	1.85,	1.71)
# Variable para el eje de abcisas de la función de densidad weibull
eje_x <- seq(1,21,1)
# Factores de relación entre los valores de potencia obtenidos desde los valores medidos y los obtenidos
# desde la función de densidad weibull
Rel_0m <- c(1.9786202,	1.713285, 1.7308071, 1.4868179, 1.4419836, 1.4082412, 1.3955166, 1.5183958, 1.4886731, 1.7619403, 1.8136051, 1.9555852)
Rel_10m <- c(1.10004409,	1.6992983,	1.6845774,	1.4648516,	1.4033297,	1.3666074,	1.3593554,	1.4782154,	1.4776561,	1.7172133,	1.8288339,	1.9423779)

## Iteramos sobre cada una de las cuatro tablas de energía para obterner los valores

## i_700_0m

for (i in 1:12) { # Iteramos para cada mes
  
  for (j in 1:24) { # Iteramos para cada hora del dia
    
    # Generamos la función de densidad weibull para estimar la energia estimada generada para cada hora
    densidad_weibull<-tibble(VelViento = eje_x, Frecuencia = dweibull(x = eje_x,shape = forma[i],scale = escala_0m[i]))
    
    # Creamos un vector temporal donde almacenaremos la energía para cada velocidad del viento
    energia_temp <- c()
    
    for (k in 1:21) { # Iteramos para las velocidades del viento de la función de densidad (21)
      
      calulo_energia <- densidad_weibull$Frecuencia[k] * 0.5 * DensAire[i] * a_i700 * (densidad_weibull$VelViento[k])^3 * (cp_i700[k] / 100) * Rel_0m[i] * 0.001 # 0.001 para pasar a kWh
      energia_temp <- c(energia_temp, calulo_energia)
    }
    
    df_energia_hora_i700_0[j,(i+1)] <- round(df_energia_hora_i700_0[j,(i+1)] * sum(energia_temp), 3)
    
  }
  
}

## i_700_10m

for (i in 1:12) { # Iteramos para cada mes
  
  for (j in 1:24) { # Iteramos para cada hora del dia
    
    # Generamos la función de densidad weibull para estimar la energia estimada generada para cada hora
    densidad_weibull<-tibble(VelViento = eje_x, Frecuencia = dweibull(x = eje_x,shape = forma[i],scale = escala_10m[i]))
    
    # Creamos un vector temporal donde almacenaremos la energía para cada velocidad del viento
    energia_temp <- c()
    
    for (k in 1:21) { # Iteramos para las velocidades del viento de la función de densidad (21)
      
      calulo_energia <- densidad_weibull$Frecuencia[k] * 0.5 * DensAire[i] * a_i700 * (densidad_weibull$VelViento[k])^3 * (cp_i700[k] / 100) * Rel_10m[i] * 0.001 # 0.001 para pasar a kWh
      energia_temp <- c(energia_temp, calulo_energia)
    }
    
    df_energia_hora_i700_10[j,(i+1)] <- round(df_energia_hora_i700_10[j,(i+1)] * sum(energia_temp), 3)
    
  }
  
}

## i_1000_0m

for (i in 1:12) { # Iteramos para cada mes
  
  for (j in 1:24) { # Iteramos para cada hora del dia
    
    # Generamos la función de densidad weibull para estimar la energia estimada generada para cada hora
    densidad_weibull<-tibble(VelViento = eje_x, Frecuencia = dweibull(x = eje_x,shape = forma[i],scale = escala_0m[i]))
    
    # Creamos un vector temporal donde almacenaremos la energía para cada velocidad del viento
    energia_temp <- c()
    
    for (k in 1:21) { # Iteramos para las velocidades del viento de la función de densidad (21)
      
      calulo_energia <- densidad_weibull$Frecuencia[k] * 0.5 * DensAire[i] * a_i1000 * (densidad_weibull$VelViento[k])^3 * (cp_i1000[k] / 100) * Rel_0m[i] * 0.001 # 0.001 para pasar a kWh
      energia_temp <- c(energia_temp, calulo_energia)
    }
    
    df_energia_hora_i1000_0[j,(i+1)] <- round(df_energia_hora_i1000_0[j,(i+1)] * sum(energia_temp), 3)
    
  }
  
}

## i_1000_10m

for (i in 1:12) { # Iteramos para cada mes
  
  for (j in 1:24) { # Iteramos para cada hora del dia
    
    # Generamos la función de densidad weibull para estimar la energia estimada generada para cada hora
    densidad_weibull<-tibble(VelViento = eje_x, Frecuencia = dweibull(x = eje_x,shape = forma[i],scale = escala_10m[i]))
    
    # Creamos un vector temporal donde almacenaremos la energía para cada velocidad del viento
    energia_temp <- c()
    
    for (k in 1:21) { # Iteramos para las velocidades del viento de la función de densidad (21)
      
      calulo_energia <- densidad_weibull$Frecuencia[k] * 0.5 * DensAire[i] * a_i1000 * (densidad_weibull$VelViento[k])^3 * (cp_i1000[k] / 100) * Rel_10m[i] * 0.001 # 0.001 para pasar a kWh
      energia_temp <- c(energia_temp, calulo_energia)
    }
    
    df_energia_hora_i1000_10[j,(i+1)] <- round(df_energia_hora_i1000_10[j,(i+1)] * sum(energia_temp), 3)
    
  }
  
}

# Obtenemos la energía media generada (kWh) cada día para cada mes del año y el total para cada configuración
a <- colSums(df_energia_hora_i700_0)
# 0.986   1.308   1.887   1.760   1.687   1.546   1.151   1.161   0.922   0.969   0.865   1.105
Total_a <- sum(a) * 30.42
# 
b <- colSums(df_energia_hora_i700_10)
# 0.979   2.237   3.045   2.874   2.729   2.518   1.955   1.960   1.658   1.692   1.582   1.916
Total_b <- sum(b) * 30.42
#
c <- colSums(df_energia_hora_i1000_0)
# 1.422   1.886   2.721   2.566   2.466   2.271   1.687   1.691   1.334   1.401   1.243   1.588
Total_c <- sum(c) * 30.42
#
d <- colSums(df_energia_hora_i1000_10)
# 1.386   3.163   4.270   4.065   3.887   3.617   2.864   2.856   2.435   2.452   2.268   2.718
Total_c <- sum(c) * 30.42
#


# Guardamos las tabalas de energía en sendos archivos
write.csv(df_energia_hora_i700_0, file = "Energia_i700_0m.csv", row.names = FALSE)
write.csv(df_energia_hora_i700_10, file = "Energia_i700_10m.csv", row.names = FALSE)
write.csv(df_energia_hora_i1000_0, file = "Energia_i1000_0m.csv", row.names = FALSE)
write.csv(df_energia_hora_i1000_10, file = "Energia_i1000_10m.csv", row.names = FALSE)

## Para trabjar con un entorno mas limpio, eliminamos algunas variables cuando comenzamos con los cálculos de energía
## remove(hora, columna, contador, filas, files,H, H00, h00, H06, h06, H12, h12, H18, h18, i, j, medias_mensuales, mes, meses, raiz_temp, z, df_temp, df_VVhoraria_Meses, df_VVInterp_Meses)

## Eliminamos las variables del entorno 
## rm(list=ls())
