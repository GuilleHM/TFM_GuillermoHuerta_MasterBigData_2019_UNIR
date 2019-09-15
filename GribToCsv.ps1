<# 

Este "script" toma los archivos .grb obtenidos desde el MARS de la ECMWF con las componentes u y v de velocidad del viento
a 10 metros de altura para la posición N36.4300, W-6.2300 y los transforma en archivos .csv, limpiando los campos que
no nos serán útiles para realizar la posterior fase de análisis de los mismos

#>

# Establecemos el directorio de trabajo y donde se encontrarán los archivos sobre los que queremos trabajar
# NO PUEDE HABER NINGÚN OTRO ARCHIVO EN EL DIRECTORIO
$directorio = Set-Location C:\Users\GuilleHM\TFM\ERAInterim\GRIB_Files

# Lista con trodos los archivos sobre la que iteraremos
$archivos = Get-ChildItem $directorio

# Iteramos sobre cada uno de los archivos
foreach ($a in $archivos){
    $b = $a.Name.Substring(0,21) + "csv"
    grib_get_data $a.Name > $b 

    $content = [System.IO.File]::ReadAllText(".\TFM\ERAInterim\GRIB_Files\$b").Replace("Latitude, Longitude, Value`r`n",
    "").Replace("36.430", "").Replace("-6.230","").Replace(" ","")
    [System.IO.File]::WriteAllText(".\TFM\ERAInterim\GRIB_Files\$b", $content)
}

