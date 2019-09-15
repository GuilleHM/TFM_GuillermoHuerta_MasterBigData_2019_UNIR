## Este "script" nos sirve para calcular la velocidad media mensual del viento para 
## cada uno de los meses del año en la localización de la estación meteorológica 5972X
## de la Aemet. Para ello utiliza los datos obtenidos desde la API AEMET OpenData en el
## periodo Ene 1999 - Abr 2019. Asímismo, calcula la media móvil de las medias mensuales
## para el mismo periodo, con el objetivo de evaluar una posible tendencia de las medidas 
## en dicho periodo.
## Por otro lado, calcula y dibuja, a partir de los mismos datos, la distribución Weibull 
## para cada mes en la localización de la estación FROGGIT, empleando los factores de regresión
## calculados para la correlación de las estaciones 5972X y FROGGIT

## ---------------------------------------------------------------------------- ##

# Cargamos las bibliotecas que nos harán falta
library(tidyverse)  
library(lubridate) 
library(MASS) 
library(stringr) 
library(zoo)
library(viridis)
library(broom)
library(plotly)
library(knitr) 
library(ggplot2)
library(fitdistrplus)
library(devtools)
library(ggpubr)

# Selecionamos el tema o formato general para las visualizaciones
theme_set(theme_minimal())

# Configuramos el directorio de trabajo donde colocaremos los archivos con los datos
# de viento de la estación Froggit, de la estación 5972X y los obtenidos desde la web PVGIS
setwd("C:\\Users\\GuilleHM\\Desktop")

# Creamos un vector con los meses para la etiqueta del eje x de los gráficos mensuales
meses <- c("ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC")

## ------------------------------------------------------------------------- ##

## Cálculo media mensual para el periodo 1999-2019 de los datos de la estación
## 5972X (San Fernando) de la Aemet

# Creamos una tabla con la fecha y la velocidad media diaria
aemet_data = read_csv('aemetclimafechavelviento19992019.csv',col_types=cols(), col_names = TRUE)
colnames(aemet_data) <- c("Fecha", "VV_AEMET")

# Agrupamos los valores por meses y calculamos la media mensual
aemet_means<-aemet_data %>%
  mutate(mes=month(Fecha), diasenelmes=days_in_month(Fecha)) %>%
  dplyr::select(-Fecha) %>%
  group_by(mes) %>%
  summarise(VelMediaMensual=mean(VV_AEMET,na.rm=T),
            diasenelmes=mean(diasenelmes))
  
# Media de las medias mensuales
momm<-weighted.mean(aemet_means$VelMediaMensual,aemet_means$diasenelmes)
# 3,61 m/s

# Creamos un vector con los meses para la etiqueta del eje x
meses <- c("ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC")

# Dibujamos un gráfico temporal con la media mensual para cada mes del año
ggplot(aemet_means,aes(x=mes,y=VelMediaMensual)) +
  geom_line(colour="red", size=1.25) +
  ggtitle("Velocidad media mensual estación 5972X Aemet (1999 - 2019)") +
  labs(x= "Mes", y= "VelocidadViento (m/s)") +
  scale_y_continuous(limits = c(0, 6)) +
  scale_x_continuous(breaks=c(1:12),labels=meses) +
  theme(axis.line= element_line(colour = "black", size= 1.5, linetype= "solid"))
  scale_color_viridis(discrete=T) 

# Dibujamos un gráfico de caja y bigotes con las medias diarias para cada mes del año
aemet_mensual <- aemet_data %>%
  mutate(mes=month(Fecha)) %>%
  dplyr::select(-Fecha) %>%
  group_by(mes)

ggplot(aemet_mensual,aes(factor(mes),VV_AEMET))+ 
  geom_boxplot(color="#0f0b7d", fill="#edb2b5", notch=FALSE)+
  ggtitle("Velocidad media diaria del viento en la estación 5972X (1999 - 2019)") +
  scale_x_discrete(breaks=c(1:12),labels=meses) +
  labs(x= "Mes (Valores de 2019 solo hasta Abril)", y= "VelocidadViento_m/s (Datos AEMET Opendata)") +
  theme(axis.line= element_line(colour = "darkblue", size= 1.5, linetype= "solid"))

## -------------------------------------------------------------------------- ##
  
## Calculamos las medias mensuales para cada año (normalizadas) para confirmar su consistencia 
## a lo largo del tiempo, es decir, confirmar que no haya una dervia significativa en el tiempo

# Cambiamos el formato de los valores medios mensuales para poder realizar una unión de tablas
aemet_means<-aemet_data %>%
  mutate(mes=month(Fecha)) %>%
  dplyr::select(-Fecha) %>%
  group_by(mes) %>%
  summarise_all('mean',na.rm=T) %>%  
  gather(Vel_Viento,VV_AEMET,-mes)

# Calculamos el valor normalizado de la media mensual para cada mes
aemet_normalizado_mensual<-aemet_data %>%
  gather(Vel_Viento,VV_AEMET,-Fecha) %>%
  mutate(AñoMes=as.Date(cut(Fecha,'month'))) %>%
  group_by(Vel_Viento,AñoMes) %>%
  summarise(ws=mean(VV_AEMET,na.rm=T)) %>%
  mutate(mes=month(AñoMes)) %>%
  left_join(aemet_means,c('Vel_Viento','mes')) %>%
  mutate(VV_AEMET_Normalizada=ws/VV_AEMET) %>%
  ungroup()

# Calculamos la media móvil (12 meses) del valor normalizado anterior (para disminuir el ruido 
# provocado por las oscilaciones mensuales)
mediamovil_normalizada_aemet<-aemet_normalizado_mensual %>%
  group_by(Vel_Viento) %>%
  mutate(rolling_mean_aemet=rollmean(VV_AEMET_Normalizada,12,fill = NA,align='left'))

# Dibujamos el gráfico
ggplotly(
  ggplot(mediamovil_normalizada_aemet,aes(AñoMes,rolling_mean_aemet,colour="Media Móvil (12 meses)"))+
    geom_line(size=1.5)+
    geom_line(aes(AñoMes, VV_AEMET_Normalizada, colour="Media Mensual Normalizada"), mediamovil_normalizada_aemet, size=0.5)+
    scale_y_continuous(labels=scales::percent) +
    ggtitle("Evolución de la Media Mensual de la Velocidad del Viento para la Estación 5972X de la AEMET (1999 - 2019)") +
    labs(x= "Año", y= "VelocidadViento Normalizada (%)") +
    scale_color_manual(name="",values=c("#CC6666", "#9999CC")) +
    theme(axis.line= element_line(colour = "grey", size= 1.5, linetype= "solid"))
)

## --------------------------------------------------------------------------- ##

## Cálculo de la distribución de frecuencias de la velocidad del viento para
## el punto de instalación de la estación FROGGIT, para cada mes del año.
## A partir de esas distribuciones mensuales, calculamnos las densidades de potencia.

# Creamos la tabla donde guardaremos los valores mensuales par el punto de 
# instalación FROGGIT. NOTA: Max 700 valores diarios, i.e. datos de 22,5 años)
mensuales_froggit <- setNames(data.frame(matrix(ncol = 12, nrow = 700)), meses)

# Tomamos los valores de densidad del aire calculados en el "script" <DensidadAire20052019_CercaEstaciónFroggit.R>
DensAire <- c(1.247, 1.241, 1.233, 1.221, 1.208, 1.199, 1.190, 1.185, 1.195, 1.204, 1.227, 1.242)

# Creamos la lista donde almacenaros los gráficos para los 12 meses
lg <- list()

# Creamos los vectores donde almacenaremos las tablas de densidad de potencia para cada mes
# calculada a partir de los valores medidos y de los obtenidos de la distribución Weibull estimada
densidad_potencia <- c()
dens_pot_weib <- c()

# Creamos los vectores donde almacenaremos los valores de energía generada para cada mes
# para cada uno de los dos modelos de aerogeneradores elegidos

Energia_mes_i700 <- c()
Energia_mes_i1000 <- c()

# Coeficientes de la regresión con la estación 5972X de la AEMET para poder
# extrapolar los valores historicos de esta estación al punto de
# instalacón de la estación FROGGIT
Interseccion <- 0.0351
Pendiente <- 0.9233

# Secuencia de valores para crear el eje x (0.01 m/s) de la función de densidad tipo weibull calculada
x<-seq(0,15,.01)

# Guardamos, para los modelos i-700 e i-1000, el área y los coeficientes de potencia calculados en el "script" <Cp.R>
a_i700 <- 2.83
a_i1000 <- 3.98
# Eliminamos el Cp correspondiente a 0 m/s para casar los valores con los contenedores de 1m/s de la tabla para el
# cálculo de la energía "df_ener_i700" y "df_ener_i1000"
cp_i700 <- c(0.000000,0.000000,0.000000,35.989501,34.714282,29.324779,29.377437,26.992126,25.474763,23.321197,
             20.875412,18.661223,16.773884,15.109295,13.137421,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000)
cp_i1000 <- c(0.000000,0.000000,0.000000,32.079530,37.956567,34.218165,29.926644,25.663624,22.531110,19.709663,
              17.431242,15.445699,14.951535,14.216001,13.383024,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000)

# Calculamos los datos de velocidad media mensual, los parámetros de la función de distribuión Weibull estimada,
# guardamos el gráfico y, finalmente, calculamos la densidad de potencia para cada uno de los meses
for (i in 1:12) {

  # Agrupamos los valores historicos diarios (1999-2019) de la estación 5972X por meses 
  valores_mensuales <- aemet_data %>%
    mutate(mes=month(Fecha)) %>%
    dplyr::select(-Fecha) %>%
    group_by(mes) %>%
    filter(mes==i)
  
  # Aplicamos los coeficientes
  recta_regresion <- c(Interseccion + valores_mensuales$VV_AEMET * Pendiente, rep(NA, 700 - length(valores_mensuales$VV_AEMET)))
  
  # Guardamos los datos en la columna del mes correspondiente en la tabla mensuales FROGGIT
  mensuales_froggit[,i] <- recta_regresion
  
  ##################################################################################################
  ## Esta sección sirve para el cálculo de la velocidad del viento 10 metros por encima del punto ##
  ## donde se encuentra la estación FROGGIT. Se emplea dicha velocidad (mayor por el efecto       ##
  ## cizalladura debido al suelo) en caso de que se opte por instalar el aerogenerador con una    ##
  ## torre que lo eleve a dicha altura. Habrá que tener en cuenta la relación coste extra de      ##
  ## instalación de la torre y beneficio obtenido por mayor viento en altura.                     ##
  ## Activar o desactivar en función de si se quieren los datos para una u otra altura            ##                                                                                             ##
                                                                                                  ## 
  # Rugosidad (en metros) del suelo en la zona (datos del GWA)                                    ##
  Ro <- 0.3                                                                                       ##
  # Altura de la estación FROGGIT (en metros)                                                     ##
  h1 <- 10                                                                                        ##
  # Altura par la que queremos saber la velocidad del viento (en metros)                          ##
  h2 <- 20                                                                                        ##
  # Velocidad a 10 metros arriba del punto de medida de la estación FROGGIT                       ##
  mensuales_froggit[,i] <- mensuales_froggit[,i] * (log(h2/Ro)/log(h1/Ro))                        ##
  ##################################################################################################
  
  # Calculamos la media para ese mes
  Media_Mensual <- round(mean(mensuales_froggit[,i], na.rm = TRUE),2)
  
  # Ajustamos la distribución Weibull a los valores de la estación que queramos (AEMET o FROGGIT)
  # distribucion_weibull<-fitdistr(valores_mensuales$VV_AEMET[!is.na(valores_mensuales$VV_AEMET)],'weibull')
  distribucion_weibull<-fitdistr(mensuales_froggit[,i][!is.na(mensuales_froggit[,i])],'weibull')
  
  # Generamos la función de densidad para incluirla en el grafico
  densidad_weibull<-tibble(x,y=dweibull(x = x,shape = distribucion_weibull$estimate[1],scale = distribucion_weibull$estimate[2]))
  
  # Guardamos cada uno de los gráficos en la lista  
  lg[[i]] <- ggplot(mensuales_froggit,aes(mensuales_froggit[,i]))+
    geom_histogram(aes(y=..density..),bins=15, color='white', fill="darkblue")+ 
    geom_line(data=densidad_weibull,aes(x=x,y=y),color='red', size=1)+
    ggtitle(meses[i]) +
    labs(#title=paste('Distribución frecuencias VV ', meses[i],  'Punto Instalación Estación Froggit'),
         x=paste('VV (m/s) - Vel. Media: ', Media_Mensual),
         y='Frecuencia') +
    theme(axis.line= element_line(colour = "grey", size= 1.5, linetype= "solid"),
          plot.title = element_text(size = 10, face = "bold"),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    annotate("text", x = 11, y = 0.26, colour = "black", size= 4,
             label = paste("A= ", round(distribucion_weibull$estimate[2],2), "  k= ", round(distribucion_weibull$estimate[1],2))) +
    annotate("rect", xmin = 7, xmax = 15, ymin = 0.22, ymax = 0.3, fill = "orange",alpha = .5)
  
  ## Cálculo de la densidad de potencia
  
  # Agrupamos los valores de velocidad media diaria del viento para ese mes en un vector temporal
  # en grupos de 0.1, desde 0 hasta 20 m/s
  vect_temp <- cut(mensuales_froggit[,i], seq(0,20,.1))
  # Guardamos en una variable temporal las frecuencias para cada uno de esos grupos
  tabla_temp <- table(vect_temp)
  # Creamos la tabla que con las columnas que emplearemos para el cálculo de la desidad de potencia
  df_denspot <- data.frame(tabla_temp, VV = seq(0.1,20,.1) )
  # Eliminamos la columna con los agrupamientos de la variable temporal
  df_denspot$vect_temp <- NULL
  
  # Calculamos la densidad de potencia para cada mes y la guardamos en el correspondiente vector,
  # tanto para los valores medidos como para los obtenidos de la distribución weibull estimada
  densidad_mensual <- weighted.mean(0.5 * DensAire[i] * (df_denspot$VV^3), df_denspot$Freq, na.rm = TRUE)
  dens_potmes_weib <- weighted.mean(0.5 * DensAire[i] * (densidad_weibull$x^3), densidad_weibull$y)
  densidad_potencia <- c(densidad_potencia, densidad_mensual)
  dens_pot_weib <- c(dens_pot_weib, dens_potmes_weib)
  
  # A continuación los valores para la altura del punto de instalación de la estacón FROGGIT (10m)
  # DensPotMedida: 30.87692 44.07205 61.09019 63.10333 61.68120 57.50202 43.77443 41.27121 34.63912 32.26840
  # 29.16303 34.06320
  # DensPotWeibul: 28.12459 41.13775 56.92972 60.17395 59.07039 55.24662 42.10895 39.23718 33.02527 29.98382
  # 26.96883 31.09208
  # ((densidad_potencia - dens_pot_weib)/ dens_pot_weib)*100
  # 9.786202 7.132850 7.308071 4.868179 4.419836 4.082412 3.955166 5.183958 4.886731 7.619403
  # 8.136051 9.555852
  # mean(((densidad_potencia - dens_pot_weib)/ dens_pot_weib)*100)
  # 6.411226
  
  # A continuación los valores para una altura 10m sobre el punto de instalación de la estacón FROGGIT (i.e., 20m)
  # DensPotMedida: 53.12084  75.54969 104.39079 108.17344 105.56684  98.38091  74.96610  70.65115  59.45913
  # 55.20561  50.16636  58.39021
  # DensPotWeibul: 48.28974  70.61182  97.70231 103.36835 101.47409  94.90174  72.36560  67.42670  56.74850
  # 51.51116  46.32665  53.36154
  # ((densidad_potencia - dens_pot_weib)/ dens_pot_weib)*100
  # 10.004409  6.992983  6.845774  4.648516  4.033297  3.666074  3.593554  4.782154  4.776561
  # 7.172133  8.288339  9.423779
  # mean(((densidad_potencia - dens_pot_weib)/ dens_pot_weib)*100)
  # 6.185631
  
  ## Los valores estimados de densidad de potencia desde los valores medidos medios para cada mes
  ## son, de media, alrededor de un 6% mayores que los estimados desde la correspondiente distribución weibull
  
  ## Calculamos las energías teóricas mensuales para cada modelo y para la altura de referencia
  ## de la estación meteorológica FROGGIT y 10 metros por encima de esta.
  
  # Agrupamos los valores de velocidad media diaria del viento para ese mes en un vector temporal,
  # en este caso, en grupos de 1, desde 0 hasta 21 m/s
  vect_temp2 <- cut(mensuales_froggit[,i], seq(0,21,1))
  # Guardamos en una variable temporal las frecuencias para cada uno de esos grupos
  tabla_temp2 <- table(vect_temp2)
  # Averiguamos el número de medidas (para obterner luego la frecuencia relativa en la tabla "df_ener")
  longitud <- length(mensuales_froggit[,i][!is.na(mensuales_froggit[,i])])
  # Creamos la tabla que con las columnas que emplearemos para el cálculo de la energia mensual generada por cada modelo de aerogenerador
  df_ener <- data.frame(tabla_temp2, VV = seq(1,21,1), Cp_i700 = cp_i700, Cp_i1000 = cp_i1000)
  df_ener$Energia_i700_kWh <- (df_ener$Freq / longitud) * 0.5 * DensAire[i] * a_i700 * (df_ener$VV)^3 * (df_ener$Cp_i700 / 100) * 0.73 # 0.73 = 730 (num.horas medias mes)/ 1000 (para pasar a KWh)
  df_ener$Energia_i1000_kWh <- (df_ener$Freq / longitud) * 0.5 * DensAire[i] * a_i1000 * (df_ener$VV)^3 * (df_ener$Cp_i1000 / 100) * 0.73
  
  # Incluimos la energía generada por ese mes en el vector correspondiente
  Energía_mes_i700 <- c(Energía_mes_i700, round(sum(df_ener$Energia_i700_kWh),2))
  Energía_mes_i1000 <- c(Energía_mes_i1000, round(sum(df_ener$Energia_i1000_kWh),2))
}

# Creamos una tabla con los valores de energía obtenidos para cada mes
DF_ENER <- data.frame(I700 = Energía_mes_i700, I1000 = Energía_mes_i1000, MESES = c(1:12))

# Organizamos todos los gráficos de curvas de viento en un solo gráfico
grafico <- ggarrange(lg[[1]], lg[[2]], lg[[3]], lg[[4]], lg[[5]], lg[[6]],
          lg[[7]], lg[[8]], lg[[9]], lg[[10]], lg[[11]], lg[[12]],
          #labels = meses,
          ncol = 3, nrow = 4)

# Dibujamos el gráfico conjunto de curvas de viento
annotate_figure(grafico,
                top = text_grob("Distribución de la Velocidad del Viento para cada mes del año en el Punto de Instalación de la Estación FROGGIT",
                                color = "black", face = "bold", size = 14))

# Guardamos los valores para cada mes en una tabla
write.csv(mensuales_froggit, file = "Valorespormescalculadoslugarfroggit19992019_10m.csv", row.names = FALSE)
# Para el caso de altura 10 metros por encima de la estación FROGGIT: "Valorespormescalculadoslugarfroggit19992019_20m.csv"

# Calculamos la energía anual teórica prevista para cada modelo de aerogenerador
Energía_anual_i700 <- sum(Energía_mes_i700)
Energía_anual_i1000 <- sum(Energía_mes_i1000)

# Dibujamos el gráfico con la energía generada por mes para cada aerogenerador
ggplot(DF_ENER, aes(x = MESES)) +                    
  geom_line(aes(y=I700), colour="lightblue", size=1.5) + 
  geom_line(aes(y=I1000), colour="brown", size=1.5) +
  scale_x_continuous(breaks=c(1:12), labels = meses) +
  scale_y_continuous(limits = c(0, 120)) +
  labs(title='Energía Teórica Mensual Generada por los Aerogeneradores Modelo i-700 e i-1000 a la Altura de la Estación Meteorológica FROGGIT',
       x='Mes',
       y='Energía Teórica Generada (kW_h)') +
  theme(axis.line= element_line(colour = "grey", size= 1.5, linetype= "solid"),
        plot.title = element_text(size = 10, face = "bold"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()) +
  annotate("text", x = 10.5, y = 90, colour = "lightblue", size= 6,
           label = paste("i-700, Total: ", Energía_anual_i700)) + 
  annotate("text", x = 10.5, y = 100, colour = "brown", size= 6,
           label = paste("i-1000, Total: ", Energía_anual_i1000))


##########################################################################################################################
## ENERGÍA/MES - i700 (Alt. FROGGIT) : 22.20 31.55 42.39 45.44 44.73 43.23 33.16 31.17 24.64 23.15 21.21 24.37          ##
## ENERGÍA/MES - i1000 (Alt. FROGGIT) : 32.00 45.41 59.98 64.46 63.36 61.02 46.87 43.89 35.77 33.27 31.09 34.69         ##
## ENERGÍA/MES - i700 (Alt. 10m + FROGGIT) : 36.40 51.85 67.11 74.30 73.66 71.10 57.54 52.83 45.21 39.32 35.93 39.56    ##
## ENERGÍA/MES - i1000 (Alt. 10m + FROGGIT) : 51.07 70.81 91.64 101.73 100.57 98.13 80.13 72.77 62.77 55.47 51.02 55.15 ##
##########################################################################################################################


## --------------------------------------------------------------------------------- ##


# Eliminamos las variables del entorno 
rm(list=ls())


## ---------------------------------- PRUEBAS -------------------------------------- ##
# j <- 12
# 
# distribucion_weibull<-fitdistr(mensuales_froggit[,12][!is.na(mensuales_froggit[,12])],'weibull')
# 
# densidad_weibull<-tibble(x,y=dweibull(x = x,shape = distribucion_weibull$estimate[1],scale = distribucion_weibull$estimate[2]))
# 
# Media_Mensual <- round(mean(mensuales_froggit[,12], na.rm = TRUE),2)
# 
# lg[[12]] <- ggplot(mensuales_froggit,aes(mensuales_froggit[,12]))+
#   geom_histogram(aes(y=..density..),bins=15, color='white', fill="darkblue")+ 
#   geom_line(data=densidad_weibull,aes(x=x,y=y),color='red', size=1)+
#   ggtitle(meses[12]) +
#   labs(#title=paste('Distribución frecuencias VV ', meses[i],  'Punto Instalación Estación Froggit'),
#     x=paste('VV (m/s) - Vel. Media: ', Media_Mensual),
#     y='Frecuencia') +
#   theme(axis.line= element_line(colour = "grey", size= 1.5, linetype= "solid"),
#         plot.title = element_text(size = 10, face = "bold"),
#         panel.grid.major = element_blank(),
#         panel.grid.minor = element_blank()) +
#   annotate("text", x = 11, y = 0.26, colour = "black", size= 4,
#            label = paste("A= ", round(distribucion_weibull$estimate[2],2), "  k= ", round(distribucion_weibull$estimate[1],2))) +
#   annotate("rect", xmin = 7, xmax = 15, ymin = 0.22, ymax = 0.3, fill = "orange",alpha = .5)
