## Este "script" sirve para crear una tabla con los precios de generación (PEP) y consumo (PVPC,DHA2.0 y DHA_CE),
## para una instalación de autoconsumo. Toma para ello un archivo .csv con los valores para el periodo
## Abril - Junio de 2019 ofrecidos por REE en su web.
## Calcula a partir de los datos el factor de relación entre el precio de la energía generada vertida a la red (PEP)
## y el de la energía consumida de la red (en las dos modalidades básicas para las tarifas de luz reguladas, PVPC y DHA)
## Crea, asímismo, el gráfico pra visualizar la evolución a lo largo del día de dicho factor relacional.


## ---------------------------------------------------------------------------- ##


# Cargamos las bibliotecas que nos harán falta
library(tidyverse) # Ecosistema Paquetes-r  
library(lubridate) # Formateado de fechas
library(ggplot2) # Creación gráficos

# Configuramos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\Desktop")

# Creamos una tabla con los valores obtenidos de REE
ree_data = read_csv('DatosRee_AbrJun19.csv', col_types=cols(), col_names = TRUE)
# Eliminamos las columnas que no necesitamos.
# Nos quedamos con el id (hay 4: 1739 -> Precio Energía Producida (PEP); 1013,1014 y 1015 -> PVPC, DHA y DH Coche Electrico, respectivamente)
ree_data[,2:4] <- NULL
# Pasamos los valores de UTC a CET
ree_data$datetime <- format(ree_data$datetime,usetz=TRUE,tz="CET")

# Agrupamos los valores por id y hora, y calculamos los precios medios (en ???/MWh)
ree_means<-ree_data %>%
  mutate(Hora= hour(datetime)) %>%
  dplyr::select(-datetime) %>%
  group_by(id, Hora) %>%
  summarise(PrecioMedioHorario=mean(value,na.rm=T)) %>%
  spread(id, PrecioMedioHorario)

# Cambiamos el nombre de las columnas
colnames(ree_means) <- c("Hora", "PVPC", "DHA", "DHCE", "PEP")

# Hallamos los factores de relación entre los dos precios principales para el consumo y el precio de la energía producida
# y los incluimos como sendas columnas
ree_means <- ree_means %>%
  mutate(Factor_PVPC=PVPC/PEP, Factor_DHA=DHA/PEP)

# Guardamos la tabla en un archivo .csv
write.csv(ree_means, file = "ValoresProcesadosREE.csv", row.names = FALSE)

# Calculamos la media de dichos factores
mean(ree_means$Factor_PVPC) # 2.31
mean(ree_means$Factor_DHA) # 1.88

# Creamos los gráficos para esos factores
ggplot(ree_means, aes(x = Hora)) +                    
  geom_line(aes(y=Factor_PVPC), colour="red", size=1.5) + 
  geom_line(aes(y=Factor_DHA), colour="darkblue", size=1.5) +
  scale_x_continuous(breaks=c(0:23), limits = c(0,23)) +
  scale_y_continuous(limits = c(1, 3)) +
  labs(title='Relación del Precio de la Energía Autoproducida con el de las Tarifas PVPC y DHA2.0',
       x='Hora del día',
       y='Factor de Relación') +
  theme(axis.line= element_line(colour = "grey", size= 1.5, linetype= "solid"),
        plot.title = element_text(size = 10, face = "bold"),
        panel.background = element_rect(fill = "lightyellow"),
        panel.grid.major = element_line(colour = "lightgrey")) + 
  annotate("text", x = 4, y = 2.75, colour = "red", size= 6,
           label = "PVPC") + 
  annotate("text", x = 4, y = 1.75, colour = "darkblue", size= 6,
           label = "DHA2.0")

  

## ---------------------------------------------------------------------------- ##

  
# Eliminamos las variables del entorno 
rm(list=ls())

