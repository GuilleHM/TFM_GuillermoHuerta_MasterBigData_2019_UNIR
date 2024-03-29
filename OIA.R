## Este "script" toma los datos de consumo del hogar, precio de la energ�a (generada y consumida) y
## cantidad de energ�a estimada generada por la instalac�n fotovoltaica y el aerogenerador, para 
## encontrar el punto �ptimo en la relaci�n costes de la instalaci�n / reducci�n en la factura de la luz,
## dado por el plazo de amortizaci�n de la instalaci�n.
## Una vez amortizada la instalaci�n, �sta proporcionar� un beneficio igual al ahorro en la parte
## de la factura de la luz correspondiente a la energ�a consumida multiplicado por el n�mero de a�os
## restantes hasta el plazo de v�da �til estimada para la instalaci�n (fijado en 20 a�os).
## No se tienen en cuenta costes de mantenimiento ni tampoco las bonificaciones al IBI.

## ---------------------------------------------------------------------------- ##

# Cargamos las bibliotecas que nos har�n falta
library(tidyverse) # Ecosistema Paquetes-r  
library(lubridate) # Formateado de fechas
library(ggplot2) # Creaci�n gr�ficos

# Configuramos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\Desktop")

# Creamos una tabla con los consumos medios horarios por cada periodo de facturac�n (mitad de un mes 
# y el siguiente). Este archivo se obtiene al procesar manualmente en Excel los datos obtenidos de 
# la web de Endesa Distribuci�n (24 archivos con los consumos para los dos �ltimos a�os)
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
# A�adimos una columna con la hora y reordenamos las columnas
consumos$Hora <- c(0:23)
consumos <- consumos[,c(13,1:12)]
# Eliminamos las variables temporales que no necesitamos
remove(nom_colum, cons)

# Creamos una tabla con los precios de la energ�a (la producida y la consumida). En el periodo horario
# donde la producci�n supera al consumo, el excedente se "vierte" a la red al precio fijado por el mercado
# para esa hora (nosotros emplearemos el precio estimado, bas�ndonos en los valores medios obtenidos en 
# el "script - EvaluacionPreciosREE_AbrJun2019.R"). Igualmente, en los periodos horarios de mayor consumo 
# que generaci�n, la energ�a se obtiene de la red al precio establecido para la tarifa regulada correspondiente
# (emplearemos ambas, PVPC y DHA2.0 en nuestras simulaciones)
precios = read_csv('precios.csv', col_types=cols(), col_names = TRUE)
# Dividimos entre 1000 para pasar los precios de MWh a kWh
precios [,2:5] <- precios [,2:5] / 1000

# Creamos una tabla con los valores horarios por mes generados por una instalaci�n fotovoltaica de 100Wp (p�rdidas del sitema ya incluidas)
pv <- read_csv('pv.csv', col_types=cols(), col_names = TRUE)
# Pasamos los valores de Wh a kWh
pv <- pv/1000
pv$Hora <- pv$Hora * 1000

# Creamos una tabla para cada una de las cuatro configuraciones de aerogenerador elegidas
i_700_0m <- read_csv('Energia_i700_0m.csv', col_types=cols(), col_names = TRUE)
i_700_10m <- read_csv('Energia_i700_10m.csv', col_types=cols(), col_names = TRUE)
i_1000_0m <- read_csv('Energia_i1000_0m.csv', col_types=cols(), col_names = TRUE)
i_1000_10m <- read_csv('Energia_i1000_10m.csv', col_types=cols(), col_names = TRUE)

# Aplicamos un factor de p�rdidas para cada uno de los sistemas del 10%:
# P�rdidas �hmicas: 2%
# P�rdidas en el conversor: 2%
# Potencia por debajo del valor nominal: 5%
# P�rdidas por imprevistos y paradas de mantenimieto: 1%

i_700_0m <- i_700_0m * 0.90
i_700_10m <- i_700_10m * 0.90
i_1000_0m <- i_1000_0m * 0.90
i_1000_10m <- i_1000_10m * 0.90

i_700_0m$Hora <- i_700_10m$Hora <- i_1000_0m$Hora <- i_1000_10m$Hora <- c(0:23)

## --------------------------------------------------------------------------------- ##

## Iteramos sobre dinstintas configuraciones posibles para averiguar cual ser�a la �ptima en t�rminos
## de costes de instalaci�n / ahorro de energ�a.
## Consideramos placas de 330Wp, desde ninguna (0) hasta diez (10) y nueve (9) instalaciones de aerogeneradores 
## posibles (ningun aerogenerador y 8 instalaciones -2 modelos, 2 alturas y 1 � 2 ag's- contempladas).
## En total, 99 posibles configuraciones (a,b), donde a define el n�mero de placas solares y b la
## configuraci�n de aerogenerador empleada, con:
## b = 0, ningun aerogenerador;
## b = 1, generador i_700 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 2, generador i_700 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 3, generador i_1000 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 4, generador i_1000 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 5, generador 2 x i_700 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 6, generador 2 x i_700 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 7, generador 2 x i_1000 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 8, generador 2 x i_1000 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;

## Realizaremos los c�lculos para cada una de las tres tarifas el�ctricas contempladas: PVPC, DHA y DHCE.

# Creamos una tabla y una lista temporales que utilizaremos para hacer los c�lculos para cada instalaci�n combinada (pv + wt) posible.
df_temp <- data.frame(matrix(vector(mode = 'numeric',length = 6), nrow = 24, ncol = 12))
ls_temp <- list()

# Creamos tres listas donde guardaremos los costes de la energ�a para cada una de las configuraciones
# posibles del sistema de generaci�n (pv + wt).
ls_pvpc <- ls_dha <- ls_dhce <- list()

# Creamos una lista con las tablas de datos para las configuraciones de aerogeneradores
ls_wt <- list(i_700_0m, i_700_10m, i_1000_0m, i_1000_10m, i_700_0m, i_700_10m, i_1000_0m, i_1000_10m)

# Hallamos el consumos neto (producci�n menos consumo) y calculamos su coste para cada una de las configuraciones
# Hay que ejecutar el lazo manualmente tres veces, cambiando los par�metros que se indican para obtener los valores
# para cada una de las tarifas
for (a in 0:10) { # N�mero de placas
  for (b in 0:8) { # Configurador del aerogenerador
    for (i in 1:12) { # Mes del a�o
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
          df_temp[j,i] <- df_temp[j,i] * precios[j,2] * 30.42 # 30.42: n�mero medio de d�as por mes
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

# Creamos una tabla con las tres listas de coste energ�tico
df_energia <- do.call(rbind, Map(data.frame, Coste_PVPC=ls_pvpc, Coste_DHA=ls_dha, Coste_DHCE = ls_dhce))

# Creamos una variable con el consumo total del hogar para incluirlo en el t�tulo del gr�fico
Consum_Total <- round(sum(consumos[,-1]) * 30.42,0)

ggplot(df_energia)+
  geom_line(aes(x=c(1:99),y= Coste_PVPC),color='#3c51a3', size=1.25)+
  geom_line(aes(x=c(1:99),y= Coste_DHA),color='green', size=1.25)+
  geom_line(aes(x=c(1:99),y= Coste_DHCE),color='brown', size=1)+
    labs(title= paste("Gasto anual en energ�a seg�n la configuraci�n elegida para el sistema de autoconsumo (fv + ag) conectado a red - (Consumo:", Consum_Total, "kWh / a�o)"),
    x="Configuraci�n sitema autoconsumo (99 opciones: consultar tabla configuraciones) // X ps = X panel(-es) solar(-es)",
    y='Gasto anual en energ�a (???)') +
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
  
################################ CODIFICACI�N SISTEMA AUTOCONSUMO #######################################

## N�mero de m�dulos fotovoltaicos de 330 Wp (a): Cociente X / 9, siendo X el n�mero del eje de abcisas.
## Configuraci�n del aerogenerador (b): Resto X / 9, con:
## b = 0, ningun aerogenerador;
## b = 1, 1 x generador i_700 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 2, 1 x generador i_700 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 3, 1 x generador i_1000 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 4, 1 x generador i_1000 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 5, 2 x generador i_700 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 6, 2 x generador i_700 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 7, 2 x generador i_1000 a 0m sobre la altura de la estaci�n meteorol�gica FROGGIT;
## b = 8, 2 x generador i_1000 a 10m sobre la altura de la estaci�n meteorol�gica FROGGIT;

#########################################################################################################

## --------------------------------------------------------------------------------- ##

## C�lculamos cu�l es la instalaci�n �ptima, considerando como tal la que tenga un menor plazo de amortizaci�n

# Creamos una tabla con los costes de instalaci�n para las distintas configuraciones posibles
# (rese�ar aqu� que s�lo hemos considerado instalaciones con ning�n o con dos AG del mismo modelo, ya que el inversor
# necesita se�ales de, al menos, 70 Voltios y los aerogeneradores proporcionan salidas de 48V)
costes = read_csv('costes', col_types=cols(), col_names = TRUE)

# Incluimos la opci�n de una subvenci�n hipot�tica del 45% para la parte e�lica de instalaciones mixtas
# Para emplear esta tabla, hay que sustituir "costes" por 2costes2" en los dos bucles for
# costes2 = read_csv('CostesTotalesInstalaci�nAutoconsumo_SubvencionHipotetica.csv', col_types=cols(), col_names = TRUE)

# Creamos una tabla donde guardaremos el plazo de amortizaci�n para cada configuraci�n
amortizacion_pvpc <- as.data.frame(matrix(0, ncol = 11, nrow = 5))
amortizacion_dha <- as.data.frame(matrix(0, ncol = 11, nrow = 5))

# Hacemos el c�lculo del plazo de amortizaci�n para las tarifas pvpc y dha (la tarifa dhce pr�cticamente no se diferencia
# de la tarifa dha, a no ser que haya un consumo considerable en horario nocturno - i.e. carga coche el�ctrico -)

# Creamos sendos contadores para recorrer el n�mero de placas y la configuraci�n del AG seleccionado
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

# Nombramos las columnas con el n�mero de placas solares de la instalaci�n
colnames(amortizacion_pvpc) <- colnames(amortizacion_dha) <- c(0:10)

# Pasamos las tablas a matrices para poder dibujar los gr�ficos
amortizacion_pvpc<- round(as.matrix(amortizacion_pvpc),2)
amortizacion_dha<- round(as.matrix(amortizacion_dha),2)

# Dibujamos un histograma para cada tarifa
barplot(amortizacion_pvpc, col=c("#3550b5", "#0339fc", "#5173f0", "#8d9fe3", "#cdd6fa"),
        main="Plazo de amortizaci�n - Tarifa PVPC",
        xlab= "N�mero de placas solares", ylab= "A�os", ylim=c(0,25), 
        args.legend = list(x=50, y=30,bty = "n"),
        legend.text=c("Sin AG","2 x i_700_0m", "2 x i_700_10m", "2 x i_1000_0m", "2 x i_1000_10m"), beside = T)

barplot(amortizacion_dha, col=c("#c72626", "#fc0303", "#fa6161", "#e68e8e", "#f2dfdf"),
        main="Plazo de amortizaci�n - Tarifa DHA",
        xlab= "N�mero de placas solares", ylab= "A�os", ylim=c(0,25), beside = T,
        args.legend = list(x=50, y=30,bty = "n"),
        legend.text=c("Sin AG","2 x i_700_0m", "2 x i_700_10m", "2 x i_1000_0m", "2 x i_1000_10m"))


# Eliminamos las variables del entorno 
rm(list=ls())