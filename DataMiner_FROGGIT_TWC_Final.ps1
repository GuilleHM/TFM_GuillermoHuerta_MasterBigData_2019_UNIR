# Solicitamos y guardamos en mongodb los datos para cada día (datos cada 5 minutos) de los meses que especificamos
# (aquellos entre $MesInicial y $MesFinal) desde la web "The Weather Company", donde se almacenan los datos que recoge
# la estación meteorológica FROGGIT


# Comenzamos definiendo las credenciales de acceso a la API de "The Weather Company" 
$APIKEY = "X"


# Establecemos el directorio de trabajo
Set-Location C:\Users\GuilleHM\TFM\FROGGIT


# Definimos un array con los caracteres necesarios para los meses en la llamada a la API (requiere formato YYYYMMDD)
# Los días se recorreran en el loop for interno. El año queda fijo en 2019
$Mes = "01","02", "03","04", "05", "06", "07", "08", "09", "10", "11", "12"  

$MesInicial = 3
$MesFinal = 5

# Cabecera y pie para formar el archivo javascript que utilizamos en la llamada a mongodb para la carga de datos
$header = "db = db.getSiblingDB(`"froggit`")`;`r`ndb.datos_wu.insertMany([`r`n" 
$footer = "])`;"
# Cargamos la cabecera
Add-Content -Path .\DatosTWC.js $header

# Recorremos cada uno de los meses
for($i=$MesInicial; $i -le $MesFinal; $i++){

    $k = 1

    #Definimos cuantos días tenemos que iterar para cada mes
    if($i -eq 4 -or $i -eq 6 -or $i -eq 9 -or $i -eq 11){
    $k = 30
    }
    elseif($i -eq 2){
    $k = 28 # Hay que cambiar este valor a 29 para años bisiestos
    }
    else{
    $k = 31
    }

    # Recorremos todos los días del mes
    for ($j=1; $j -le $k; $j++){

        # El formato de llamada a la API requiere que incluyamos siempre dos dígitos para el día
        if ($j -le 9) {[string]$Dia = "0$j"}
        else {[string]$Dia = "$j"}
        
    
        # Llamada a la API para la obtención del uri desde el que descargar los datos
        $ParamsInvCli = @{ 'Method' = 'Get';
                           'Uri'="https://api.weather.com/v2/pws/history/all?stationId=ISANFERN28&format=json&units=m&date=2019" + $Mes[$i-1] + $Dia + "&apiKey=" + $APIKEY
                         }

        $apicall = Invoke-RestMethod @ParamsInvCli -OutFile .\WU_TWC_Froggit.js


        # Creación del archivo DatosTWC_Utf8.js que cargará automáticamente los documentos en la colección "datos_wu"
        # de la BBDD "froggit" en el disco duro local. La variable $bytes sirve para eliminar los caracteres "{"observations":" 
        # al inicio del archivo y "}" al final. Esto es necesario para poder usar InsertMany en la llamada a mongodb
        $bytes = [System.IO.File]::ReadAllBytes("C:\Users\GuilleHM\TFM\FROGGIT\WU_TWC_Froggit.js")
        [System.IO.File]::WriteAllBytes("C:\Users\GuilleHM\TFM\FROGGIT\WU_TWC_Froggit.js",$bytes[17..($bytes.count-3)])

        # Añadimos lo datos para cada día y una "," para separarlos de los del día siguiente
        Add-Content -Path .\DatosTWC.js -Value (Get-Content -Path .\WU_TWC_Froggit.js)
        Add-Content -Path .\DatosTWC.js ","
        
        # Limpieza del archivo para la siguiente ejecución del ciclo
        Clear-Content -Path .\WU_TWC_Froggit.js
        
    }
}

# Limpiamos la última "," para poder procesar el archivo sin errores
$bytes = [System.IO.File]::ReadAllBytes("C:\Users\GuilleHM\TFM\FROGGIT\DatosTWC.js")
[System.IO.File]::WriteAllBytes("C:\Users\GuilleHM\TFM\FROGGIT\DatosTWC.js",$bytes[0..($bytes.count-4)])

# Añadimos el pie al archivo y lo guardamos en otro con codificación UTF-8 (para evitar problemas en la carga a mongodb)
Add-Content -Path .\DatosTWC.js $footer
Get-Content -Path .\DatosTWC.js | Set-Content -Encoding utf8 -Path .\DatosTWC_Utf8.js

# Carga de los datos en mongodb
$respmongo = mongo localhost:27017 .\DatosTWC_Utf8.js

# Limpieza de los archivos para la siguiente ejecución del script
Clear-Content -Path .\DatosTWC.js
Clear-Content -Path .\DatosTWC_Utf8.js



