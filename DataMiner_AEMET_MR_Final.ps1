<#

Este script se encarga de la recogida automatica (programada en el Programador de Tareas de Windows 10 para ejecutarse 
todos los días a las 14:35h, con dos intentos adicionales a las 14:45 y 14:55 en caso de fallo de ejecución) tanto de 
los datos meteorologicos como de los de radiación (la API los ofrece por separado) de todas las estaciones meteorológicas
de España que la API AEMET Opendata proporciona. Asímismo, ejecuta el volcado de esos datos en la BBDD "aemet" de un
servidor mongodb instalado en la máquina local. Envía un correo electrónico para avisar del resultado de la operación.

#>


# Comenzamos definiendo variales generales de acceso a la API y el servidor smtp para el envío del email

$APIKEY = "X"
$password = ConvertTo-SecureString 'X' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ('guillermo.huerta529@comunidadunir.net', $password)

# Establecemos el directorio de trabajo

Set-Location C:\Users\GuilleHM\TFM\OpendataAEMET

# Limpiamos los archivos empleados para el procesado y descarga de los datos del dia anterior, para poder utilizarlos
# en la descarga y procesado de datos meteorologicos (en primer lugar) y radiación (en segundo).

Clear-Content -Path .\Miner.js
Clear-Content -Path .\Loader.js
Clear-Content -Path .\LoaderUtf8.js


<# Datos meteorológicos #>

# Llamada a la API para la obtención del uri desde el que descargar los datos

$ParamsInvMet = @{ 'Method' = 'Get';
                   'Uri'='https://opendata.aemet.es/opendata/api/observacion/convencional/todas/?api_key=' + $APIKEY
                 }

$apicallmet = Invoke-RestMethod @ParamsInvMet

# Si la llamada a la API no devuelve "exito", envia un correo de aviso y sale del script

if ($apicallmet.descripcion -ne "exito"){
    Send-MailMessage -From 'guillermo.huerta529@comunidadunir.net' -To 'guillehm1@gmail.com' -Subject 'FALLO Volcado Datos Meteorologicos' -Body "API: $apicallmet" -SmtpServer 'smtp.office365.com' -Port '587' -UseSsl -Credential $credential
    Exit   
}

# Obtención de los datos meteorologicos (desde el uri devuelto por la API) y volcado al archivo intermedio Miner.js

$ParamsInvMet.Uri = $apicallmet.datos

Invoke-RestMethod @ParamsInvMet -OutFile .\Miner.js

# Creación del archivo MeteorologicosUtf8.js que cargará automaticamente los documentos en la colección "meteorologicos" de la BBDD "aemet" en el disco duro local

$header = "db = db.getSiblingDB(`"aemet`")`;`r`ndb.meteorologicos.insertMany(`r`n"
$footer = ")`;"

Add-Content -Path .\Loader.js $header
Add-Content -Path .\Loader.js -Value (Get-Content -Path .\Miner.js)
Add-Content -Path .\Loader.js $footer
Get-Content -Path .\Loader.js | Set-Content -Encoding utf8 -Path .\LoaderUtf8.js

# Carga de los datos meteorologicos en mongodb

$respmongo = mongo localhost:27017 .\LoaderUtf8.js

# Envío de un corrreo con el resultado de la operación. Aquí comprobamos que la carga a mongodb ha sido correcta

Send-MailMessage -From 'guillermo.huerta529@comunidadunir.net' -To 'guillehm1@gmail.com' -Subject 'Resultado Volcado Datos Meteorologicos' -Body "API: $apicallmet`r`n`r`nMONGO: $respmongo" -SmtpServer 'smtp.office365.com' -Port '587' -UseSsl -Credential $credential

#Limpieza de los archivos para la ejecución captura y procesado de los datos de radiación

Clear-Content -Path .\Miner.js
Clear-Content -Path .\Loader.js
Clear-Content -Path .\LoaderUtf8.js


<# Datos radiación #>

#Los primeros pasos son identicos a la obtención de los datos meteorologicos, excepto el uri

$ParamsInvRad = @{ 'Method' = 'Get';
                   'Uri'='https://opendata.aemet.es/opendata/api/red/especial/radiacion/?api_key=' + $APIKEY
                 }

$apicallrad = Invoke-RestMethod @ParamsInvRad

if ($apicallrad.descripcion -ne "exito"){
    Send-MailMessage -From 'guillermo.huerta529@comunidadunir.net' -To 'guillehm1@gmail.com' -Subject 'FALLO Volcado Datos Radiación' -Body "API: $apicallrad" -SmtpServer 'smtp.office365.com' -Port '587' -UseSsl -Credential $credential
    Exit   
}

$ParamsInvRad.Uri = $apicallrad.datos

Invoke-RestMethod @ParamsInvRad -OutFile .\Miner.csv

# El archivo que devuelve la API es tipo csv, por lo que necesitamos trabajar sobre el para convertirlo a formato json

# En primer lugar eliminamos las tres primeras líneas, que ofrecen una cabecera que no es util para la conversión del archivo a json

$LinesCount = $(get-content -Path .\Miner.csv).Count
get-content -Path .\Miner.csv |
    select -Last $($LinesCount-3) | 
    set-content -Path .\Minertemp.csv
Move-Item -Path .\Minertemp.csv -Destination .\Miner.csv -Force

# Creamos el archivo con la cadena json. Para ello es neesario añadir al archivo una cabecera con un valor unico para
# campo en cada uno de los documentos json que resultarán de la conversión

import-csv -Delimiter ';' -Path .\Miner.csv `
-Header 'Estación','Indicativo','TipoGL','5GL','6GL','7GL','8GL','9GL','10GL','11GL','12GL','13GL','14GL','15GL','16GL','17GL','18GL','19GL','20GL','SUMAGL','TipoDF','5DF','6DF','7DF','8DF','9DF','10DF','11DF','12DF','13DF','14DF','15DF','16DF','17DF','18DF','19DF','20DF','SUMADF','TipoDT','5DT','6DT','7DT','8DT','9DT','10DT','11DT','12DT','13DT','14DT','15DT','16DT','17DT','18DT','19DT','20DT','SUMADT','TipoUV','4.5UV','5UV','5.5UV','6UV','6.5UV','7UV','7.5UV','8UV','8.5UV','9UV','9.5UV','10UV','10.5UV','11UV','11.5UV','12UV','12.5UV','13UV','13.5UV','14UV','14.5UV','15UV','15.5UV','16UV','16.5UV','17UV','17.5UV','18UV','18.5UV','19UV','19.5UV','20UV','SUMAUV','TipoIR','1IR','2IR','3IR','4IR','5IR','6IR','7IR','8IR','9IR','10IR','11IR','12IR','13IR','14IR','15IR','16IR','17IR','18IR','19IR','20IR','21IR','22IR','23IR','24IR','SUMAIR' `
| ConvertTo-Json | Add-Content -Path .\Miner.js

# Creamos un objeto con el que poder trabajar desde el archivo con la cadena json. Este paso es necesario para organizar
# los respectivos valores de radiación en sendos arrays (en lugar de que cada valor aparezca como un campo independiente) 

$jsonarray = Get-Content -Raw -Path .\Miner.js | ConvertFrom-Json

foreach($doc in $jsonarray){

    # Borramos campos que no aportan valor al documento

    $doc.PSObject.properties.remove('TipoGL')
    $doc.PSObject.properties.remove('TipoDF')
    $doc.PSObject.properties.remove('TipoDT')
    $doc.PSObject.properties.remove('TipoUV')
    $doc.PSObject.properties.remove('TipoIR')

    # Creamos los arrays para cada tipo de radiación

    $doc | Add-Member -MemberType NoteProperty -Name Radiación_GL -value (New-object System.Collections.Arraylist)
    $doc | Add-Member -MemberType NoteProperty -Name Radiación_DF -value (New-object System.Collections.Arraylist)
    $doc | Add-Member -MemberType NoteProperty -Name Radiación_DT -value (New-object System.Collections.Arraylist)
    $doc | Add-Member -MemberType NoteProperty -Name Radiación_UV -value (New-object System.Collections.Arraylist)
    $doc | Add-Member -MemberType NoteProperty -Name Radiación_IR -value (New-object System.Collections.Arraylist)

    # Asignamos el valor de cada campo al array correspondiente. Dejamos fuera de la asignación los campos
    # "Estación", "Indicativo" y la "SUMA" para cada tipo de raciadión
        
    foreach($doc_property in $doc.PsObject.Properties){
    
                
        if($doc_property.Name -match "Estación" -or $doc_property.Name -match "Indicativo" -or $doc_property.Name -match "SUMA" -or $doc_property.Name -match "Radiación") {continue}

        if($doc_property.Name -match "GL"){
        
        $doc.Radiación_GL.Add($doc_property.Value)
        
        }

        if($doc_property.Name -match "DF"){
        
        $doc.Radiación_DF.Add($doc_property.Value)
        
        }

        if($doc_property.Name -match "DT"){
        
        $doc.Radiación_DT.Add($doc_property.Value)
        
        }

        if($doc_property.Name -match "UV"){
        
        $doc.Radiación_UV.Add($doc_property.Value)
        
        }

        if($doc_property.Name -match "IR"){
        
        $doc.Radiación_IR.Add($doc_property.Value)
        
        }

        # Una vez asignado el valor del campo a su correspondiente array, eliminamos el campo

        $doc.PSObject.properties.remove($doc_property.Name)
   }
}

# Creamos el archivo "RadiacionUtf8.js" que será el que emplearemos en la llamada al shell de mongo para la introducción
# de los documentos en la colección "radiacion" de la BBDD "aemet" en el servidor mongodb instalado en la maquina local

# Cabecera que añadiremos al archivo

$header = "db = db.getSiblingDB(`"aemet`")`;`r`ndb.radiacion.insertMany(`r`n"

# Pie del archivo. En él, se incluyen los comandos necesarios para incluir un campo con una cadena de caracteres
# correspondiente a la fecha de los datos de radiación obtenidos de la API como valor. Este paso es necesario ya que 
# el archivo csv original que envía la API solo incluye la fecha una vez en la primera linea (eliminada en el procesamiento
# realizado en las lineas de codigo comentadas mas arriba) del mismo.

$footer = ")`;`r`nvar d = new Date()`;`r`nd.setDate(d.getDate() - 1)`;`r`nvar iso = d.toISOString()`;`r`nvar n = iso.slice(0, -5);`r`ndb.radiacion.updateMany({`"fint`": {`$exists: false}},{`$set: {`"fint`": n}})`;"

# Añadimos la cabecera, el contenido del objeto $jsonarray (convertido a una cadena json) y el pie. Nos aseguramos de
# que el archivo quede codificado en utf-8 para evitar problemas en la isercción de los documentos en mongo

Add-Content -Path .\Loader.js $header
Add-Content -Path .\Loader.js ($jsonarray | ConvertTo-Json)
Add-Content -Path .\Loader.js $footer
Get-Content -Path .\Loader.js | Set-Content -Encoding utf8 -Path .\LoaderUtf8.js

# Insertamos los documentos en mongo

$respmongo = mongo localhost:27017 .\LoaderUtf8.js

# Enviamos un correo electrónico con el resultado de la operación

Send-MailMessage -From 'guillermo.huerta529@comunidadunir.net' -To 'guillehm1@gmail.com' -Subject 'Resultado Volcado Datos Radiacion' -Body "API: $apicallrad`r`n`r`nMONGO: $respmongo" -SmtpServer 'smtp.office365.com' -Port '587' -UseSsl -Credential $credential


<# Volvemos a poner el equipo en modo hibernación #>

Add-Type -Assembly System.windows.Forms
[System.windows.Forms.Application]::SetSuspendState("Hibernate", $false, $false)
