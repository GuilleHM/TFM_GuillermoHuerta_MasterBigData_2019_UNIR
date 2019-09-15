## Este "Script" calcula el coeficiente de potencia (Cp), para cada uno de los aerogeneradores
## incluidos en la colección "eolicos" de la BBDD "generadores" del despliegue mongodb local

# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\TFM\\Generadores")

# Incluimos la librería necesaria para trabajar con archivos json  
library(rjson) #importar archivos json 

# Creamos un vector con los nombres del archivo para cada generador y otro con sus diametros
archivos <- c("mongoexport_GENERADOR_i300_12V.json", "mongoexport_GENERADOR_l500_24V.json",
              "mongoexport_GENERADOR_i700_24V.json", "mongoexport_GENERADOR_i1000_24V.json",
              "mongoexport_GENERADOR_i1500_48V.json", "mongoexport_GENERADOR_i2000_48V.json")
diametros <- c(1.03, 1.15, 1.90, 2.25, 2.25, 2.25)

# Creamos una lista donde almacenaremos los coeficientes de potencia
Cp <- list()

for (g in 1:length(archivos)){

# Importamos la curva de potencia para un modelo de turbina
power_json <- fromJSON(file = archivos[g])

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
  
  # Vector con las velocidades para las que determinaremos el Cp (0-20, cada 1 m/s)
  VV <- c(0:20)
  
  # Vector con la densidad de potencia máxima para cada una de las velocidades del vector VV
  dens_pot_max <- c(0, 0.6, 4.9, 16.5, 39.2, 76.2, 132.3, 210.1, 313.6, 446.5, 612.5, 815.2,
                    1058.4, 1345.7, 1680.7, 2067.2, 2508.8, 3009.2, 3572.1, 4201.1, 4900.0, 5672.4)
  
  # Diametro del rotor (en m)
  diam <- diametros[g]
  
  # Area de barrido del aerogenerador
  area <- ((diam/2)^2)*3.1416
  
  # Máxima energía teórica para el área de rotor del aerogenerador en cuestión
  potencia_max <- dens_pot_max * area
  
  # Energía del aerogenerado para cada velocidad
  potencia_aerog <- c()
  
  n <- 1
  m <- ncol(power_df)
  for (j in 1:length(VV)){
    if (VV[j] > power_df[2,m]){break}
    else if (power_df[2,n] == VV[j]){
      potencia_aerog <- c(potencia_aerog, power_df[1,n])
      n <- n + 1
    }
    else {
    pot_temp <- approx(c(power_df[2,(n-1)], power_df[2,n]), c(power_df[1,(n-1)], power_df[1,n]), VV[j])
    potencia_aerog <- c(potencia_aerog, pot_temp[[2]])
    }
  }
  
  # Calculamos el coeficiente de potencia y lo guardamos en la lista
  Cp [[g]] <- (potencia_aerog / potencia_max) * 100
  Cp [[g]][1] <- 0
}

VV <- c(VV, 0)

# Dibujamos un gráfico con las seis curvas
par(mfrow=c(3,2), title)
plot(VV, Cp[[1]], type= "l", main= "Modelo i-300",
     xlab="Velocidad del Viento (m/s)", ylab="Cp (%)",
     pch=20, col = 'red')
plot(VV, Cp[[2]], type= "l", main= "Modelo l-500",
     xlab="Velocidad del Viento (m/s)", ylab="Cp (%)",
     col = 'blue')
plot(VV, Cp[[3]], type= "l", main= "Modelo i-700",
     xlab="Velocidad del Viento (m/s)", ylab="Cp (%)",
     col = 'brown')
plot(VV, Cp[[4]], type= "l", main= "Modelo i-1000",
     xlab="Velocidad del Viento (m/s)", ylab="Cp (%)",
     col = 'green')
plot(VV, Cp[[5]], type= "l", main= "Modelo i-1500",
     xlab="Velocidad del Viento (m/s)", ylab="Cp (%)",
     col = 'orange')
plot(VV, Cp[[6]], type= "l", main= "Modelo i-2000",
     xlab="Velocidad del Viento (m/s)", ylab="Cp (%)",
     col = 'purple')
mtext("Coeficientes de Potencia", side = 3, line = -2, outer = TRUE)

# Borramos las variables del entorno
rm(list=ls())


