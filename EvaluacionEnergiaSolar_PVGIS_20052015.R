## Este "script" sirve para crear una tabla con los valores de generación energética por hora (Wh) en cada
## mes del año para un sistema fotovoltaico conectado a red (SFCR) de 100 Wp en el punto de instalación de 
## la estación meteorológica FROGGIT. 
## Crea, asímismo, el gráfico pra visualizar la evolución a lo largo del año de dicha capacidad generadora.


## ---------------------------------------------------------------------------- ##


# Cargamos las bibliotecas que nos harán falta
library(tidyverse) # Ecosistema Paquetes-r  
library(lubridate) # Formateado de fechas
library(ggplot2)

# Configuramos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\Desktop")

# Creamos una tabla con la fecha y la energía producida (Wh)
pvgis_data = read_csv('data_pvgis_procesado20052015.csv', col_types=cols(), col_names = TRUE)
# Eliminamos las columnas que no necesitamos
pvgis_data[,3:9] <- NULL
# Cambiamos los nombres a las columnas
colnames(pvgis_data) <- c("Fecha", "E_Wh")
# Eliminamos el caracter ":" de la columna fecha, para poder procesar el valor con la función ymd_hm
pvgis_data$Fecha <- gsub(":", "", pvgis_data$Fecha)
# Damos formato a la fecha para poder trabajar con ella
pvgis_data$Fecha <- ymd_hm(pvgis_data$Fecha)
# Pasamos los valores de UTC a CET
pvgis_data$Fecha <- format(pvgis_data$Fecha,usetz=TRUE,tz="CET")

# Agrupamos los valores por meses y hora, y calculamos los valores medios
pvgis_means<-pvgis_data %>%
  mutate(hora= hour(Fecha), mes=month(Fecha)) %>%
  dplyr::select(-Fecha) %>%
  group_by(hora, mes) %>%
  summarise(EnergiaMediaHoraria=mean(E_Wh,na.rm=T))

# Factorizamos la columna de los meses para poder utilizar el vector de factores como agrupamiento
# en el gráfico, y poder incluir todas las gráficas de manera conjunta en el mismo
Mes <- factor(pvgis_means$mes)

# Dibujamos el gráfico
ggplot(pvgis_means,aes(hora,EnergiaMediaHoraria, group=mes, color=Mes))+
  geom_line(size=1)+
  ggtitle("Variación a lo largo del Año de la Generación de Energía Horaria para una Instalación Fotovoltaica de 100 Wp en el punto FROGGIT") +
  labs(x= "Hora del día", y='Energía generada (wh)') +
  scale_x_continuous(breaks=c(0:23), limits = c(0,23)) +
  scale_color_discrete()

# Creamos una tabla con una mejor disposición para trabajar luego en el "script" OIA.R (Optimización Instalación Autoconsumo)
ValoresHorarios_Mes <- pvgis_data %>%
  mutate(hora= hour(Fecha), mes=month(Fecha)) %>%
  dplyr::select(-Fecha) %>%
  group_by(mes, hora) %>%
  summarise(EnergiaMediaHoraria=mean(E_Wh,na.rm=T)) %>%
  spread(mes, EnergiaMediaHoraria, fill = NA, convert = FALSE, drop = TRUE,
         sep = NULL)
# Cambiamos el nombre a las columnas para mayor claridad
colnames(ValoresHorarios_Mes) <- c("Hora", "PV_ENE", "PV_FEB", "PV_MAR", "PV_ABR", "PV_MAY", "PV_JUN", "PV_JUL", "PV_AGO", "PV_SEP", "PV_OCT", "PV_NOV", "PV_DIC")

# Escribimos la tabla a un archivo .csv
write.csv(ValoresHorarios_Mes, file = "ValoresHorariosMesInstalacionFV100Wp.csv", row.names = FALSE)

## ---------------------------------------------------------------------------- ##

  
# Eliminamos las variables del entorno 
rm(list=ls())

