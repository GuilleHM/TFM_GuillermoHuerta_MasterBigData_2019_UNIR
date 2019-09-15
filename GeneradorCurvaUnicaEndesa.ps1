<# 

Este script toma los archivos .csv para los consumos energéticos mensuales (valores horarios) obtenidos desde la web
de Endesa Distribución (los 24 últimos meses) y genera un único archivo .csv con el consumo por horas
para esos 24 meses.

#>

# Establecemos el directorio de trabajo y donde se encontrarán los archivos sobre los que queremos trabajar
# NO PUEDE HABER NINGÚN OTRO ARCHIVO EN EL DIRECTORIO
$directorio = Set-Location C:\Users\GuilleHM\TFM\CurvasCargaENDESA\Consumos_Jun2017Jun2019

# Archivo que generaremos
$archivofinal = "consumosendesa.csv"

# Lista con trodos los archivos sobre la que iteraremos
$archivos = Get-ChildItem $directorio

# Tomamos la cabecera de uno de los archivos y la establecemos para el archivo final
Get-Content $archivos[0] -First 1 | Set-Content $archivofinal


foreach ($a in $archivos){

    Get-Content $a.FullName | # Obtenemos el contenido de cada archivo
    Select-Object -skip 1 |   # Eliminamos la cabecera
    Add-content $archivofinal # Añadimos el contenido al archivo final

}