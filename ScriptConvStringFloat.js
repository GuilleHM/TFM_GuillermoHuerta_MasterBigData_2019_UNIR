//Definimos una lista con las claves de los campos cuyos valores queremos convertir de cadena a coma flotante.

var fields = ["tmin", "tmax", "tmed", "prec", "velmedia", "racha", "sol", "presMax", "presMin"];

//Seleccionamos la BBDD sobre la que queremos trabajar

db = db.getSiblingDB("aemet");

//Recorremos la coleccion y comprobamos si no extiste alguno de los campos cuyas claves claves se han definido arriba.
//En caso de que no exista, se crea el campo y se le asigna el valor "N/A" (tipo cadena)

for (var i = 0; i<fields.length; ++i){ 
    db.climatologicos.updateMany({[fields[i]]: {$exists : false}}, {$set: {[fields[i]]: 'N/A'}});
}

//Realizamos la conversión para cada uno de los campos en cada documento. Si el valor NO es tipo cadena, no se hace nada.
//"parseFloat" devuelve NaN (tipo doble) en caso de no poder realizar el parseado.
//Finalmente, para cada documento, se guardan los cambios de vuelta en la colección de la BBDD.

var json = db.climatologicos.find();
var docs = json.toArray();
var i = 0;

for (; i<docs.length; i++){

    for (var j= 0; j<fields.length; j++){ 

    	if (typeof docs[i][fields[j]] === 'string' || docs[i][fields[j]] instanceof String){
	
	docs[i][fields[j]] = parseFloat(docs[i][fields[j]].replace(",","."));
	
	}

	/*if (isNaN(docs[i][fields[j]])){
       	continue;
    	}*/
    
    }

db.climatologicos.save(docs[i]);

}
  