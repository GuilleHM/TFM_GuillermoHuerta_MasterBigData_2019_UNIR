""" Scraper sobre la web de IstaBreeze para obtener las características de los modelos seleccionados
como representativos para el analisis de viabilidad de la instalación eolico-solar """

#importamos los paquetes necesarios
from selenium import webdriver
from bs4 import BeautifulSoup
import json

#creamos una lista con las urls de los modelos seleccionados
url_list = ["https://www.istabreeze.com/online/Windgenerator/i-300-12v-Windgenerator-iSTA-BREEZE", \
            "https://www.istabreeze.com/online/Windgenerator/L-500-24V-Windgenerator-iSTA-BREEZE-Land-Edition", \
            "https://www.istabreeze.com/online/Windgenerator/i-700-24V-Windgenerator-iSTA-BREEZE", \
            "https://www.istabreeze.com/online/Windgenerator/i-1000-24V-Windgenerator-iSTA-BREEZE", \
            "https://www.istabreeze.com/online/Windgenerator/i-1500-48V-Windgenerator-iSTA-BREEZE", \
            "https://www.istabreeze.com/online/Windgenerator/i-2000-48V-Windgenerator-iSTA-BREEZE"]

#introducimos manualmente el nombre y precio de cada modelo
models = ['i-300 12V', 'L-500 24V', 'i-700 24V', 'i-1000 24V', 'i-1500 48V', 'i-2000 48V']
prices = [189, 229, 369, 459, 539, 619]

#obtenemos los datos para cada uno de los modelos
for index, item in enumerate(url_list):
    
    #creamos el objeto con el que realizaremos la conexion con el servidor web. Empleamos para ello el navegador sin cabecera PhantomJS
    driver = webdriver.PhantomJS(executable_path="C:\\Users\\GuilleHM\\Desktop\\PhantomJS\\phantomjs-2.1.1-windows\\bin\\phantomjs")
    driver.get(url_list[index])
    
    #enviamos un formulario para que cambie de aleman (idioma por defecto) a inglés
    language_code_tag = driver.find_element_by_name("language_code")
    driver.execute_script('arguments[0].value = arguments[1]', language_code_tag, 'en')
    driver.find_element_by_id("language_form").submit()

    #creamos el objeto sobre el que trabajamos para obtener los datos una vez parseado el DOM de la web
    ps = driver.page_source
    bs = BeautifulSoup(ps, 'html.parser')

    #creamos las variable que emplearemos para convertir el contenido de la tabla 'Specifications' en el diccionario data
    data ={}
    subdata ={}
    subdatatemp={}
    tempkey = ""

    #introducimos los valores que hemos decidido incluir sin 'scrapear' la web
    data.update({'MANUFACTURER': 'IstaBreeze', 'MODEL': models[index], 'PRICE': prices[index]}) 
    data['SPECIFICATIONS']={}

    #recorremos la tabla de la web y añadimos todos los campos al diccionario
    for child in bs.find('div', {'id':'tab-attribute'}).table.children:
          
        if child.name == 'thead':
            tempkey = child.td.string       
                    
        elif child.name == 'tbody':
            lista = child.find_all('td')
            i= 0
            while i < len(lista):            
                tempsubkey= lista[i].string
                subdatatemp[tempsubkey] = lista[i+1].string
                i+=2
            subdata = subdatatemp.copy()    
            data['SPECIFICATIONS'][tempkey]=subdata
            subdatatemp.clear()
            
    #empleamos el diccionario data para crear el archivo generators.json
    with open('C:\\Users\\GuilleHM\\TFM\\Generadores\\generators.json', 'a') as outfile:
       json.dump(data, outfile, sort_keys = 'true', indent = 4, separators=(',',':'), ensure_ascii=False)
       outfile.write(",\n")

""" Cuando el script ha finalizado, tenemos un archivo .json que incluye un documento con varios
subdocumentos para todos los campos deseados para cada uno de los modelos. Posteriormente, empleamos
estos documentos para realizar la carga automática en mongodb mediante la llamada a un archivo cargador
en javascript (CargadorGeneradores.js) """

  








