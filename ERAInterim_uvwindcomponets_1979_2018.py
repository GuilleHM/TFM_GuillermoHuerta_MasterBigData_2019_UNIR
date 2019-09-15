# Este "script" obtiene los datos de viento a 10m de altura cada 6 horas (0, 6, 12 y 18h) de la zona donde se encuentra instalada la estación FROGGIT,
# para cada mes del año en el periodo 1979-2018, desde la BBDD ERA-Interim de la ECMWF. Guarda los datos correspondientes a cada mes en un fichero en el
# directorio de trabajo activo.


import calendar
from ecmwfapi import ECMWFDataServer

server = ECMWFDataServer(url="https://api.ecmwf.int/v1",key="X",email="guillehm1@gmail.com")

def retrieve_interim():
    """      
       Esta función sirve para iterar eficientemente durante todos los meses del año en el periodo de años indicado, llamando a la
       función interim_request para realizar la petición de datos. El nombre del fichero de salida se almacena en la variable "target",
       (i.e., "interim_daily_197901.grb")   
    """
    yearStart = 1993
    yearEnd = 2018
    monthStart = 1
    monthEnd = 12
    for year in list(range(yearStart, yearEnd + 1)):
        for month in list(range(monthStart, monthEnd + 1)):
            startDate = '%04d%02d%02d' % (year, month, 1)
            numberOfDays = calendar.monthrange(year, month)[1]
            lastDate = '%04d%02d%02d' % (year, month, numberOfDays)
            target = "interim_daily_%04d%02d.grb" % (year, month)
            requestDates = (startDate + "/TO/" + lastDate)
            interim_request(requestDates, target)
 
def interim_request(requestDates, target):
    """      
        Función para realizar la petición de los parámetros (componentes u y v del viento a 10m de altura).
    """
    server.retrieve({
        "class": "ei",
        "stream": "oper",
        "type": "an",
        "dataset": "interim",
        "date": requestDates,
        "expver": "1",
        "repres": "sh",
        "levtype": "sfc",
        "param": "165.128/166.128",
        "step": "0",
        "domain": "g",
        "resol": "auto",
        "area": "36.48/-6.23/36.43/-6.19",
        "target": target,
        "time": "00/06/12/18",
        "padding": "0",
        "expect": "any",
        "grid": "0.75/0.75"
    })
if __name__ == '__main__':
    retrieve_interim()
