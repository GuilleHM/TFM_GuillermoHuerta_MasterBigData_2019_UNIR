## Este "script" toma los datos de consumo del hogar, precio de la energía (generada y consumida) y
## cantidad de energía estimada generada por la instalacón fotovoltaica y el aerogenerador, para 
## encontrar el punto óptimo en la relación costes de la instalación / reducción en la factura de la luz,
## dado por el plazo de amortización de la instalación.
## Una vez amortizada la instalación, ésta proporcionará un beneficio igual al ahorro en la parte
## de la factura de la luz correspondiente a la energía consumida multiplicado por el número de años
## restantes hasta el plazo de vída útil estimada para la instalación (fijado en 20 años).
## No se tienen en cuenta costes de mantenimiento ni tampoco las bonificaciones al IBI.

## ---------------------------------------------------------------------------- ##

# Cargamos las bibliotecas que nos harán falta
library(tidyverse) # Ecosistema Paquetes-r  
library(lubridate) # Formateado de fechas
library(ggplot2) # Creación gráficos

# Configuramos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\Desktop")

# Creamos una tabla con los consumos medios horarios por cada periodo de facturacón (mitad de un mes 
# y el siguiente). Este archivo se obtiene al procesar manualmente en Excel los datos obtenidos de 
# la web de Endesa Distribución (24 archivos con los consumos para los dos últimos años)
# mediante el "script" 
cons = read_csv('consumos.csv', col_types=cols(), col_names = TRUE)
# Tomamos la primera columna como los valores para la tabla transpuesta
nom_colum <- cons$Periodo
# Creamos una nueva tabla solo con las columnas con los valores medios horarios
consumos <- cons[,2:25]
# La transponemos
consumos <- as.data.frame(t(consumos), row.names = c(1:24))
# Cambiamos el nombre de las columnas para identificar claramente el periodo de cada una
colnames(consumos) <- nom_colum
# Añadimos una columna con la hora y reordenamos las columnas
consumos$Hora <- c(0:23)
consumos <- consumos[,c(13,1:12)]
# Eliminamos las variables temporales que no necesitamos
remove(nom_colum, cons)

# Creamos una tabla con los precios de la energía (la producida y la consumida). En el periodo horario
# donde la producción supera al consumo, el excedente se "vierte" a la red al precio fijado por el mercado
# para esa hora (nosotros emplearemos el precio estimado, basándonos en los valores medios obtenidos en 
# el "script - EvaluacionPreciosREE_AbrJun2019.R"). Igualmente, en los periodos horarios de mayor consumo 
# que generación, la energía se obtiene de la red al precio establecido para la tarifa regulada correspondiente
# (emplearemos ambas, PVPC y DHA2.0 en nuestras simulaciones)
precios = read_csv('precios.csv', col_types=cols(), col_names = TRUE)
# Dividimos entre 1000 para pasar los precios de MWh a kWh
precios [,2:5] <- precios [,2:5] / 1000

# Creamos una tabla con los valores horarios por mes generados por una instalación fotovoltaica de 100Wp (pérdidas del sitema ya incluidas)
pv <- read_csv('pv.csv', col_types=cols(), col_names = TRUE)
# Pasamos los valores de Wh a kWh
pv <- pv/1000
pv$Hora <- pv$Hora * 1000

# Creamos una tabla para cada una de las cuatro configuraciones de aerogenerador elegidas
i_700_0m <- read_csv('Energia_i700_0m.csv', col_types=cols(), col_names = TRUE)
i_700_10m <- read_csv('Energia_i700_10m.csv', col_types=cols(), col_names = TRUE)
i_1000_0m <- read_csv('Energia_i1000_0m.csv', col_types=cols(), col_names = TRUE)
i_1000_10m <- read_csv('Energia_i1000_10m.csv', col_types=cols(), col_names = TRUE)

# Aplicamos un factor de pérdidas para cada uno de los sistemas del 10%:
# Pérdidas óhmicas: 2%
# Pérdidas en el conversor: 2%
# Potencia por debajo del valor nominal: 5%
# Pérdidas por imprevistos y paradas de mantenimieto: 1%

i_700_0m <- i_700_0m * 0.90
i_700_10m <- i_700_10m * 0.90
i_1000_0m <- i_1000_0m * 0.90
i_1000_10m <- i_1000_10m * 0.90

i_700_0m$Hora <- i_700_10m$Hora <- i_1000_0m$Hora <- i_1000_10m$Hora <- c(0:23)

## --------------------------------------------------------------------------------- ##

## Iteramos sobre dinstintas configuraciones posibles para averiguar cual sería la óptima en términos
## de costes de instalación / ahorro de energía.
## Consideramos placas de 330Wp, desde ninguna (0) hasta diez (10) y nueve (9) instalaciones de aerogeneradores 
## posibles (ningun aerogenerador y 8 instalaciones -2 modelos, 2 alturas y 1 ó 2 ag's- contempladas).
## En total, 99 posibles configuraciones (a,b), donde a define el número de placas solares y b la
## configuración de aerogenerador empleada, con:
## b = 0, ningun aerogenerador;
## b = 1, generador i_700 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 2, generador i_700 a 10m sobre la altura de la estación meteorológica FROGGIT;
## b = 3, generador i_1000 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 4, generador i_1000 a 10m sobre la altura de la estación meteorológica FROGGIT;
## b = 5, generador 2 x i_700 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 6, generador 2 x i_700 a 10m sobre la altura de la estación meteorológica FROGGIT;
## b = 7, generador 2 x i_1000 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 8, generador 2 x i_1000 a 10m sobre la altura de la estación meteorológica FROGGIT;

## Realizaremos los cálculos para cada una de las tres tarifas eléctricas contempladas: PVPC, DHA y DHCE.

# Creamos una tabla y una lista temporales que utilizaremos para hacer los cálculos para cada instalación combinada (pv + wt) posible.
df_temp <- data.frame(matrix(vector(mode = 'numeric',length = 6), nrow = 24, ncol = 12))
ls_temp <- list()

# Creamos tres listas donde guardaremos los costes de la energía para cada una de las configuraciones
# posibles del sistema de generación (pv + wt).
ls_pvpc <- ls_dha <- ls_dhce <- list()

# Creamos una lista con las tablas de datos para las configuraciones de aerogeneradores
ls_wt <- list(i_700_0m, i_700_10m, i_1000_0m, i_1000_10m, i_700_0m, i_700_10m, i_1000_0m, i_1000_10m)

# Hallamos el consumos neto (producción menos consumo) y calculamos su coste para cada una de las configuraciones
# Hay que ejecutar el lazo manualmente tres veces, cambiando los parámetros que se indican para obtener los valores
# para cada una de las tarifas
for (a in 0:10) { # Número de placas
  for (b in 0:8) { # Configurador del aerogenerador
    for (i in 1:12) { # Mes del año
      for (j in 1:24) { # Hora del dia
        if (i < 12){
          if(b == 0){
            df_temp[j,i] <- consumos[j, (i+1)] - (a*3.3*(pv[j,(i+1)] + pv[j,(i+2)])) / 2
          }
          else{
            df_temp[j,i] <- consumos[j, (i+1)] - ((a*3.3*(pv[j,(i+1)] + pv[j,(i+2)])) / 2) - (((b %/% 5) + 1) * ((ls_wt[[b]][j,(i+1)] + ls_wt[[b]][j, (i+2)]) / 2)) # El factor " (b %/% 5) + 1" sirve para determinar si hay uno o dos aerogeneradores instalados
          }
        }
        else{
          if(b == 0){
            df_temp[j,i] <- consumos[j, (i+1)] - (a*3.3*(pv[j,(i+1)] + pv[j,(2)])) / 2
          }
          else{
            df_temp[j,i] <- consumos[j, (i+1)] - ((a*3.3*(pv[j,(i+1)] + pv[j,(2)])) / 2) - (((b %/% 5) + 1) * ((ls_wt[[b]][j,(i+1)] + ls_wt[[b]][j, (2)]) / 2))
          }
        }
        if (df_temp[j,i] > 0){ # precios [j, 2] para PVPC, precios [j, 3] para DHA y precios [j, 4] para DHA
          df_temp[j,i] <- df_temp[j,i] * precios[j,2] * 30.42 # 30.42: número medio de días por mes
        }
        else{
          df_temp[j,i] <- df_temp[j,i] * precios[j,5] * 30.42
        }
      }
    }
    ls_temp <- colSums(df_temp)
    for (k in 1:length(ls_temp)) {
      if (ls_temp[k] < 0){
        ls_temp[k] <- 0
      }
    }
    # Solo una opcion activa cada vez para rellenar la lista correspondiente
    ls_pvpc <- c(ls_pvpc, sum(ls_temp))
    # ls_dha <- c(ls_dha, sum(ls_temp))
    # ls_dhce <- c(ls_dhce, sum(ls_temp))
  }
}

# Creamos una tabla con las tres listas de coste energético
df_energia <- do.call(rbind, Map(data.frame, Coste_PVPC=ls_pvpc, Coste_DHA=ls_dha, Coste_DHCE = ls_dhce))

# Creamos una variable con el consumo total del hogar para incluirlo en el título del gráfico
Consum_Total <- round(sum(consumos[,-1]) * 30.42,0)

ggplot(df_energia)+
  geom_line(aes(x=c(1:99),y= Coste_PVPC),color='#3c51a3', size=1.25)+
  geom_line(aes(x=c(1:99),y= Coste_DHA),color='green', size=1.25)+
  geom_line(aes(x=c(1:99),y= Coste_DHCE),color='brown', size=1)+
    labs(title= paste("Gasto anual en energía según la configuración elegida para el sistema de autoconsumo (fv + ag) conectado a red - (Consumo:", Consum_Total, "kWh / año)"),
    x="Configuración sitema autoconsumo (99 opciones: consultar tabla configuraciones) // X ps = X panel(-es) solar(-es)",
    y='Gasto anual en energía (???)') +
  scale_y_continuous(limits = c(0, 400)) +
  scale_x_continuous(breaks=seq(1,99,9),labels = c("0 ps", "1 ps", "2 ps", "3 ps", "4 ps", "5 ps", "6 ps","7 ps", "8 ps", "9 ps", "10 ps"), limits = c(0,99)) +
  theme(axis.line= element_line(colour = "grey", size= 1.75, linetype= "solid"),
        plot.title = element_text(size = 10, face = "bold"),
        panel.background = element_rect(fill = "#d5f7f7"),
        panel.grid.major = element_blank()) +
  annotate("rect", xmin = 77.5, xmax = 95.5, ymin = 250, ymax = 350, fill = "white",alpha = 1)+
  annotate("text", x = 87, y = 320, colour = "#3c51a3", size= 5,
           label = "Tarifa PVPC") +
  annotate("text", x = 87, y = 300, colour = "green", size= 5,
           label = "Tarifa DHA") +
  annotate("text", x = 87, y = 280, colour = "brown", size= 5,
           label = "Tarifa DHCE")
  
################################ CODIFICACIÓN SISTEMA AUTOCONSUMO #######################################

## Número de módulos fotovoltaicos de 330 Wp (a): Cociente X / 9, siendo X el número del eje de abcisas.
## Configuración del aerogenerador (b): Resto X / 9, con:
## b = 0, ningun aerogenerador;
## b = 1, 1 x generador i_700 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 2, 1 x generador i_700 a 10m sobre la altura de la estación meteorológica FROGGIT;
## b = 3, 1 x generador i_1000 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 4, 1 x generador i_1000 a 10m sobre la altura de la estación meteorológica FROGGIT;
## b = 5, 2 x generador i_700 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 6, 2 x generador i_700 a 10m sobre la altura de la estación meteorológica FROGGIT;
## b = 7, 2 x generador i_1000 a 0m sobre la altura de la estación meteorológica FROGGIT;
## b = 8, 2 x generador i_1000 a 10m sobre la altura de la estación meteorológica FROGGIT;

#########################################################################################################

## --------------------------------------------------------------------------------- ##

## Cálculamos cuál es la instalación óptima, considerando como tal la que tenga un menor plazo de amortización

# Creamos una tabla con los costes de instalación para las distintas configuraciones posibles
# (reseñar aquí que sólo hemos considerado instalaciones con ningún o con dos AG del mismo modelo, ya que el inversor
# necesita señales de, al menos, 70 Voltios y los aerogeneradores proporcionan salidas de 48V)
costes = read_csv('costes', col_types=cols(), col_names = TRUE)

# Incluimos la opción de una subvención hipotética del 45% para la parte eólica de instalaciones mixtas
# Para emplear esta tabla, hay que sustituir "costes" por 2costes2" en los dos bucles for
# costes2 = read_csv('CostesTotalesInstalaciónAutoconsumo_SubvencionHipotetica.csv', col_types=cols(), col_names = TRUE)

# Creamos una tabla donde guardaremos el plazo de amortización para cada configuración
amortizacion_pvpc <- as.data.frame(matrix(0, ncol = 11, nrow = 5))
amortizacion_dha <- as.data.frame(matrix(0, ncol = 11, nrow = 5))

# Hacemos el cálculo del plazo de amortización para las tarifas pvpc y dha (la tarifa dhce prácticamente no se diferencia
# de la tarifa dha, a no ser que haya un consumo considerable en horario nocturno - i.e. carga coche eléctrico -)

# Creamos sendos contadores para recorrer el número de placas y la configuración del AG seleccionado
contador_ps <- contador_ag <- 2

# Iteramos para la tarifa PVPC
for (t in 2:nrow(df_energia)) {
  
  if (((t-1) %% 9) == 0) {
    
    amortizacion_pvpc[1,contador_ps] <- costes[1,(contador_ps+1)] / (df_energia$Coste_PVPC[1] - df_energia$Coste_PVPC[((contador_ps-1)*9)+1])
    contador_ps <- contador_ps + 1
    contador_ag <- 2
    
  }
  
  else if ((t-1) %% 9 >= 5) {
    
    amortizacion_pvpc[contador_ag,(contador_ps-1)] <- costes[contador_ag,contador_ps] / (df_energia$Coste_PVPC[1] - df_energia$Coste_PVPC[((contador_ps-2)*9)+ ((t-1) %% 9) + 1])
    contador_ag <- contador_ag + 1
    
  }
  
}

# Reinicializamos los contadores
contador_ps <- contador_ag <- 2

# Para la tarifa dha
for (t in 2:nrow(df_energia)) {
  
  if (((t-1) %% 9) == 0) {
    
    amortizacion_dha[1,contador_ps] <- costes[1,(contador_ps+1)] / (df_energia$Coste_DHA[1] - df_energia$Coste_DHA[((contador_ps-1)*9)+1])
    contador_ps <- contador_ps + 1
    contador_ag <- 2
    
  }
  
  else if ((t-1) %% 9 >= 5) {

    amortizacion_dha[contador_ag,(contador_ps-1)] <- costes[contador_ag,contador_ps] / (df_energia$Coste_DHA[1] - df_energia$Coste_DHA[((contador_ps-2)*9)+ ((t-1) %% 9) + 1])
    contador_ag <- contador_ag + 1
    
  }
  
}

# Nombramos las columnas con el número de placas solares de la instalación
colnames(amortizacion_pvpc) <- colnames(amortizacion_dha) <- c(0:10)

# Pasamos las tablas a matrices para poder dibujar los gráficos
amortizacion_pvpc<- round(as.matrix(amortizacion_pvpc),2)
amortizacion_dha<- round(as.matrix(amortizacion_dha),2)

# Dibujamos un histograma para cada tarifa
barplot(amortizacion_pvpc, col=c("#3550b5", "#0339fc", "#5173f0", "#8d9fe3", "#cdd6fa"),
        main="Plazo de amortización - Tarifa PVPC",
        xlab= "Número de placas solares", ylab= "Años", ylim=c(0,25), 
        args.legend = list(x=50, y=30,bty = "n"),
        legend.text=c("Sin AG","2 x i_700_0m", "2 x i_700_10m", "2 x i_1000_0m", "2 x i_1000_10m"), beside = T)

barplot(amortizacion_dha, col=c("#c72626", "#fc0303", "#fa6161", "#e68e8e", "#f2dfdf"),
        main="Plazo de amortización - Tarifa DHA",
        xlab= "Número de placas solares", ylab= "Años", ylim=c(0,25), beside = T,
        args.legend = list(x=50, y=30,bty = "n"),
        legend.text=c("Sin AG","2 x i_700_0m", "2 x i_700_10m", "2 x i_1000_0m", "2 x i_1000_10m"))


# Eliminamos las variables del entorno 
rm(list=ls())