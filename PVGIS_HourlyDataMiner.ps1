<# Este "script" sirve para descargar desde la API del PVGIS de la UE, los valores horarios estimados de producción energética 
de una instalación solar fotovoltaica para un punto (solicita por consola las coordenadas de lat. y long., la potencia
pico instalada y las pérdidas del sistema). Supone una instalación con espacio (no insertada en un edificio, es decir, con aire
que pueda refrigerar las placas por debajo de estas), y fija (sin seguimiento en ninguno de los dos ejes e instalada con
el ángulo óptimo). 
Obtiene los datos para el periodo máximo ofrecido por la web (i.e. 2005-2015). 
Guarda los datos en un archivo .csv
#>

# Establecemos el directorio de trabajo

Set-Location C:\Users\GuilleHM\TFM\PVGIS

# Obtenemos por consola los valores de latitud y longitud del lugar sobre el que queremos conseguir la información, así como
# la potencia pico y las perdidas estimadas del sistema instalado

$lat = Read-Host -Prompt 'Introduzca latitud (xx.xxx)'
$long = Read-Host -Prompt 'Introduzca longitud (xx.xxx)'
$pot = Read-Host -Prompt 'Introduzca la potencia pico instalada (xx)'
$per = Read-Host -Prompt 'Introduzca el procentaje de pérdida total en el sitema (sin el simbolo de %!!!)'

Write-Host "Descargando datos de producción estimada para el punto lat: '$lat', lon: '$long'"

# Llamada a la API de PVGIS para la obtención de los datos (para placas de 100W de potencia)
# y volcado de los mismos al archivo "data_pvgis.csv"

$ParamsInv = @{ 'Method' = 'Get';
                'Uri'='http://re.jrc.ec.europa.eu/pvgis5/seriescalc.php?lat=' + $lat + '&lon=' + $long + '&peakpower=' + $pot + '&pvtechchoice=crystSi&loss=' + $per + '&optimalangles=1&components=1'
              }


Invoke-RestMethod @ParamsInv -OutFile .\data_pvgis.csv

# Eliminamos las 10 primeras y las 13 últimas líneas, para obtener un archivo que solo tenga una línea de cabecera (para trabajar más
# comodamente con él en R). Copiampos el contenido en otro archivo

$LinesCount = $(get-content -Path .\data_pvgis.csv).Count
get-content -Path .\data_pvgis.csv |
    select -Last $($LinesCount-10) | 
    select -First 96408 |
    set-content -Path .\data_pvgis_procesado.csv
