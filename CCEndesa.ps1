<# 

Este script toma los archivos .csv para los consumos energéticos mensuales (valores horarios) obtenidos desde la web
de Endesa Distribución (los 24 últimos meses), los transforma en documentos json (con dos campos cada uno: el día y 
un array con los valores de consumo horario), genera un archivo javasript con todos los documentos y los carga en la
colección "curvasdecarga" de la base de datos "endesa" del entorno mongodb desplegado en la máquina local.

#>

# Establecemos el directorio de trabajo y donde se encontrarán los archivos sobre los que queremos trabajar
# NO PUEDE HABER NINGÚN OTRO ARCHIVO EN EL DIRECTORIO
$directorio = Set-Location C:\Users\GuilleHM\TFM\CurvasCargaENDESA\Consumos_Jun2017Jun2019

# Lista con trodos los archivos sobre la que iteraremos
$archivos = Get-ChildItem $directorio

# Cabecera y pie del archivo javascript que utilizaremos para cargar los documentos en la colección
$header = "db = db.getSiblingDB(`"endesa`")`;`r`ndb.curvasdecarga.insertMany(`r`n[" #Añadimos al final el corchete de apertura del array
$footer = "]`n)`;"

# Añadimos la cabecera al archivo
Add-Content -Path .\LoaderCurvasEndesa.js $header

# Iteramos sobre cada uno de los archivos
foreach ($a in $archivos){

    # Pasamos de .csv a .json
    import-csv $a -Delimiter ';' | ConvertTo-Json | Set-Content -Path .\CurvasEndesa.js

    # Creamos un objeto para cada archivo para poder convertir los documentos de los consumos en elementos de un array
    $jsonarray = Get-Content -Raw -Path .\CurvasEndesa.js | ConvertFrom-Json
    # $jsonarray[0] # Prueba para depurar el archivo

    foreach($doc in $jsonarray){

        # Creamos el array "Datos" donde se guardarán los datos (en lugar de que los datos aparezcan como un 
        # campo distinto dentro del documento         
        $doc | Add-Member -MemberType NoteProperty -Name Datos -value (New-object System.Collections.Arraylist)
        # $doc # Prueba para depurar el archivo
    
        # Realizamos la conversión de campo de documento a elemento de array  
        foreach($doc_property in $doc.PsObject.Properties){
    
            # No operamossobre los campos "Día" y "Datos", que serán los campos finales con los que cuente cada documento    
            if($doc_property.Name -match "Día" -or $doc_property.Name -match "Datos") {continue}

            # Añadimos el elemento al array   
            $doc.Datos.Add($doc_property.Value)
        
            # Una vez asignado el valor del campo a su correspondiente array, eliminamos el campo
            $doc.PSObject.properties.remove($doc_property.Name)
       }
    }

    # Pasamos el contenido del objeto a un archivo temporal
    Set-Content -Path .\LoaderCurvasEndesaTemp.js ($jsonarray | ConvertTo-Json)

    # La variable intermedia $bytes sirve para elminar los caracteres "[" al inicio del archivo y "]" al final.
    # Esto es necesario para poder obtener un formato correcto en el archivo javascript final con el que cargaremos
    # los datos en la colección
    $bytes = [System.IO.File]::ReadAllBytes("C:\Users\GuilleHM\TFM\CurvasCargaENDESA\Consumos_Jun2017Jun2019\LoaderCurvasEndesaTemp.js")
    [System.IO.File]::WriteAllBytes("C:\Users\GuilleHM\TFM\CurvasCargaENDESA\Consumos_Jun2017Jun2019\LoaderCurvasEndesaTemp.js",$bytes[1..($bytes.count-4)])

    # Añadimos esta "," para separar los documentos provinientes de distintos archivos
    Add-Content -Path .\LoaderCurvasEndesaTemp.js ","

    # Cargamos el contenido el el archivo cargador de datos (este archivo, a diferencia del anterior temporal, va
    # acumulando los datos que provienen de cada uno de los archivos .csv9
    Get-Content -Path .\LoaderCurvasEndesaTemp.js | Add-Content -Path .\LoaderCurvasEndesa.js
}

# Eliminamos la última "," introducida en el bucle.
$bytes = [System.IO.File]::ReadAllBytes("C:\Users\GuilleHM\TFM\CurvasCargaENDESA\Consumos_Jun2017Jun2019\LoaderCurvasEndesa.js")
[System.IO.File]::WriteAllBytes("C:\Users\GuilleHM\TFM\CurvasCargaENDESA\Consumos_Jun2017Jun2019\LoaderCurvasEndesa.js",$bytes[1..($bytes.count-4)])

# Incluimos el pie (necesario para la carga de datos)
Add-Content -Path .\LoaderCurvasEndesa.js $footer

# Aseguramos una codficación correcta para la carga de datos en mongodb
Get-Content -Path .\LoaderCurvasEndesa.js | Set-Content -Encoding utf8 -Path .\LoaderCurvasEndesaUtf8.js

# Carga de los datos meteorologicos en mongodb
$respmongo = mongo localhost:27017 .\LoaderCurvasEndesaUtf8.js

#Limpieza de los archivos para la próxima ejecución del script
Clear-Content -Path .\CurvasEndesa.js
Clear-Content -Path .\LoaderCurvasEndesa.js
Clear-Content -Path .\LoaderCurvasEndesaTemp.js
Clear-Content -Path .\LoaderCurvasEndesaUtf8.js