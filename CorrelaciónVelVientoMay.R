## Este "script" nos correlaciona las lecturas de velocidad del viento (media horaria)
## desde el 1 hasta el 31 de Mayo de 2019 para las estaciones meteorol�gicas 
## FROGGIT y 5972X, y obtiene la recta de regresi�n que emplaremos para modelar las 
## previsiones de viento a largo plazo en la localizaci�n de la estaci�n FROGGIT.

# Establecemos el directorio de trabajo
setwd("C:\\Users\\GuilleHM\\TFM\\Correlation")

# Cargamos las bibliotecas necesarias para la manipulaci�n de datos 
library(tidyverse) # Limpieza de datos (filtrado de la diferencia)
library(ggplot2) # Creaci�n del gr�fico

# Cargamos los datos (ya limpiados) provenientes de aemet y de la estaci�n meteorol�gica
# FROGGIT en sendas tablas
aemetfinal <- read.csv(file = "SalidaScriptValoresHorariosCompletosAemetMay.csv", header = TRUE, sep = ",", dec = ".")
froggit <- read.csv(file = "SalidaScriptRPromedioHorarioMay.csv", header = TRUE, sep = ",", dec = ".")

# Eliminamos "NA�s" 
Corr_df <- data.frame(Fecha = aemetfinal$FechaFinal, VelAemet = aemetfinal$VelFinal, VelFroggit = froggit$VelFinal)
Corr_df$Diff <- Corr_df$VelAemet - Corr_df$VelFroggit
Corr_df <- na.omit(Corr_df) # Nos quedamos con 663 de 744 obs

# Calculamos el coeficiente de correlaci�n
cor(Corr_df$VelAemet, Corr_df$VelFroggit, use =  "complete.obs")

# Calculamos los par�metros (a:intersecci�n, b: pendiente) de la recta de regresi�n
RegLine <- lm(VelFroggit ~ VelAemet, Corr_df)
RegLine # Coeficientes de la recta: a = 0.245, b = 0.8515

# Obtenemos los estad�sticos del c�lculo de regresi�n
RegLine2 <- Corr_df %>% do(modelo = lm(VelFroggit ~ VelAemet, data =.))
Estadisticos <- glance(RegLine2, modelo)
head(Estadisticos)

# Guardamos los par�metros de la recta en otra variable
ParamRegre<-tidy(RegLine2,modelo) %>% 
  dplyr::select(term,estimate) %>% 
  spread(term,estimate) %>%
  rename(Interseccion=`(Intercept)`, Pendiente=VelAemet)

# Dibujamos el gr�fico de dispersi�n, incluida la recta de regresi�n
ggplot(Corr_df,aes(VelAemet,VelFroggit))+
  geom_point(size=1, color = "darkblue")+
  geom_smooth(method='lm',color='red')+
  ggtitle("Recta Regresi�n Medidas Horarias Velocidad Viento (1 - 31 May 2019)") +
  labs(x= "VV(m/s) - Estaci�n 5972X Aemet", y= "VV(m/s) - Estaci�n FROGGIT") +
  scale_y_continuous(limits = c(0, 10)) +
  theme(axis.line= element_line(colour = "black", size= 1.5, linetype= "solid"))

# Limpiamos el entorno borrando todas las variables
rm(list=ls())

## El coeficiente de correlaci�n, R (0,81), indica una correlaci�n estad�sticamente significativa.
