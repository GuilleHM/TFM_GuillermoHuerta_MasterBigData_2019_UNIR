## Este script crea un gr�fico del patron de consumo el�ctrico anual del domicilio

# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\TFM\\CurvasCargaENDESA\\Consumos_Jun2017Jun2019")

# Cargamos las librerias necesarias para dibujar el gr�fico
library(ggplot2)
library(ggthemes)

# Creamos una tabla con los datos correspondientes a los dos a�os
curvaunicaendesa <- read.csv(file = "consumosendesa.csv", header = TRUE, sep = ";", dec = ",", encoding = "UTF-8")

# Creamos una tabla con los datos medios para cada hora en esos dos a�os
mediahoraria <- data.frame(Hora = seq(0,23), consumomedio = rep(0,24))

for (i in 2:ncol(curvaunicaendesa)) {
  
  mediahoraria$consumomedio[i-1] <- mean(curvaunicaendesa[[i]],na.rm = TRUE)
  
}

# Obtenemos el m�nimo y el m�ximo
Minimo <- round(min(mediahoraria$consumomedio, na.rm = TRUE),3)
Maximo <- round(max(mediahoraria$consumomedio, na.rm = TRUE),3)

# Creamos un objeto que contiene el gr�fico
curvamediahoraria <- ggplot(mediahoraria, aes(x=Hora, y=consumomedio)) + 
                     geom_line(colour="green", size=1.5) +
                     geom_point() +
                     ggtitle("Consumo medio por horas (Jun 2017 - Jun 2019)") +
                     labs(y= paste("Consumo (kWh) - Min: ", Minimo, " / Max: ", Maximo)) +
                     theme_economist_white()

# Dibujamos el gr�fico (a�adiendo algunas caracter�sticas extra).
# Si queremos la versi�n sin zoom, debemos eliminar la escala que aparece al final
curvamediahoraria + theme(plot.title = element_text(hjust = 0.90)) + scale_y_continuous(limits = c(0, 0.16))

# Eliminamos las variable del entorno
rm(list=ls())
