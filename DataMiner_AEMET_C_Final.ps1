<#

Este "script" nos permite obtener desde la API AEMET OpenData los valores climatológicos (diarios) de un año para 
todas las estaciones meteorológicas de la Agencia de Meteorología Española.
Solicita al usuario que introduzca por teclado el año del que se desea obtene los datos.
Los datos se guardan en la colección "climatologicos" de la BBDD "aemet" en el sistema mongodb desplegado en la 
máquina local

#>


# Comenzamos definiendo variales generales de acceso a la API y el servidor smtp para el envío del email

$APIKEY = "X"
$password = ConvertTo-SecureString 'X' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ('guillermo.huerta529@comunidadunir.net', $password)

# Establecemos el directorio de trabajo

Set-Location C:\Users\GuilleHM\TFM\OpendataAEMET

# Solicita el año del que se quiere obtener los datos

$año = Read-Host -Prompt 'Introduzca el año (YYYY)'
Write-Host "Obteniendo datos para el año '$año'"

<# Datos climatológicos #>

# Solicitamos y guardamos en mongodb los datos para cada mes (el máximo plazo que permite la API) del año

for ($i=1;$i -le 12;$i++){
    
    [string]$j = "$i"
    $k = "0"

    if($i -eq 4 -or $i -eq 6 -or $i -eq 9 -or $i -eq 11){
    $k = "30"
    }
    elseif($i -eq 2){
    $k = "28" # Hay que cambiar este valor a 29 para años bisiestos
    }
    else{
    $k = "31"
    }

    # Llamada a la API para la obtención del uri desde el que descargar los datos

    $ParamsInvCli = @{ 'Method' = 'Get';
                       'Uri'="https://opendata.aemet.es/opendata/api/valores/climatologicos/diarios/datos/fechaini/" + $año + "-" + $j + "-00T00%3A00%3A01UTC/fechafin/" + $año + "-" + $j + "-" + $k + "T23%3A59%3A59UTC/todasestaciones/?api_key=" + $APIKEY
                     }

    $apicallcli = Invoke-RestMethod @ParamsInvCli

    # Si la llamada a la API no devuelve "exito", envia un correo de aviso y sale del script

    if ($apicallcli.descripcion -ne "exito"){
        Send-MailMessage -From 'guillermo.huerta529@comunidadunir.net' -To 'guillehm1@gmail.com' -Subject 'FALLO Volcado Datos Climatologicos' -Body "API: $apicallcli" -SmtpServer 'smtp.office365.com' -Port '587' -UseSsl -Credential $credential
        Exit   
    }

    # Obtención de los datos climatologicos (desde el uri devuelto por la API) y volcado al archivo intermedio DataMiner.js

    $ParamsInvCli.Uri = $apicallcli.datos

    Invoke-RestMethod @ParamsInvCli -OutFile .\Clima.js

    # Creación del archivo ClimatologicosUtf8.js que cargará automaticamente los documentos en la colección "climatologicos" de la BBDD "aemet" en el disco duro local

    $header = "db = db.getSiblingDB(`"aemet`")`;`r`ndb.climatologicos.insertMany(`r`n" 
    $footer = ")`;"

    Add-Content -Path .\Climatologicos.js $header
    Add-Content -Path .\Climatologicos.js -Value (Get-Content -Path .\Clima.js)
    Add-Content -Path .\Climatologicos.js $footer
    Get-Content -Path .\Climatologicos.js | Set-Content -Encoding utf8 -Path .\ClimatologicosUtf8.js

    # Carga de los datos meteorologicos en mongodb

    $respmongo = mongo localhost:27017 .\ClimatologicosUtf8.js

    # Envío de un corrreo con el resultado de la operación. Aquí comprobamos que la carga a mongodb ha sido correcta

    # Send-MailMessage -From 'guillermo.huerta529@comunidadunir.net' -To 'guillehm1@gmail.com' -Subject 'Resultado Volcado Datos Climatologicos' -Body "API: $apicallcli`r`n`r`nMONGO: $respmongo" -SmtpServer 'smtp.office365.com' -Port '587' -UseSsl -Credential $credential

    #Limpieza de los archivos para la ejecución captura y procesado de los datos climatologicos

    Clear-Content -Path .\Clima.js
    Clear-Content -Path .\Climatologicos.js
    Clear-Content -Path .\ClimatologicosUtf8.js
}


