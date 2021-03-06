#!/bin/bash

#script per la creazione delle curve in formato Garmin


#carica il file di configuraione delle variabili
source "./configurazione"


# Verifica che sia presente mkgmap.jar per convertire in formato garmin i file OSM
if [[ ! -e $mkgmap ]]
then
  echo "Non trovo $mkgmap, assicurati di averlo scaricato o di"
  echo "aver seguito il percorso giusto"
  exit 4
fi


# Verifica che sia presente splitter.jar per convertire in formato garmin i file OSM
if [[ ! -e $splitter ]]
then
  echo "Non trovo $splitter, assicurati di averlo scaricato o di"
  echo "aver seguito il percorso giusto"
  exit 3
fi


#verifica che sia presente Gmaptool
if [[ ! -e $GMT ]]
then
  echo "Non trovo gmt, se non lo hai già scaricato lo trovi qui:"
  echo "http://www.gmaptool.eu"
  echo "oppure controlla di averlo messo nel percorso giusto"
  exit 2
fi


#verifica che sia presente la cartella con i file del DTM5 convertiti in OSM
if [[ ! -d $uscitaosm ]]
then
  echo "Non esiste la cartella $uscitaosm, fai girare lo script shpaosm.sh e uniscibdtre.sh prima di questo"
  exit 1
fi


#crea la cartella per i file IMG se non è già esistente
if [ -d $uscitaimg ]; then
    echo "$uscitaimg esiste."
else
    mkdir $uscitaimg
fi


#cancella i file eventualmente presenti nella cartella
rm -r $uscitaimg/*


#elimina il file curve_licenza.txt
rm ./stile_garmin/curve_licenza.txt


#fa una copia del file licenza.txt e lo rinomina in curve_licenza.txt
cp ./stile_garmin/licenza.txt ./stile_garmin/curve_licenza.txt


#chiede il nome e cognome per l'attribuzione della licenza e lo inserisce nel file curve_licenza.txt al posto di "Licenziatario"
echo
echo
echo -n "inserisci il tuo nome e cognome per l'attribuzione: "
read parola

sed -i "s/licenziatario/$parola/" ./stile_garmin/curve_licenza.txt


#copia i file delle curve in sezioni
cp $uscitaosm/*.* $uscitaimg


#passa nella cartella dei file img
cd $uscitaimg


#ciclo che rinomina i file e rende i nomi con tre cifre, per cui il 19 diventa 019 ecc.....
#oltre il numero 100 lascia il numero uguale ed elimina solo la parte testuale precedente il numero e l'estensione del file
    for filename in $(ls *.pbf); do

       # vediamo che numero è il file, isolandolo tra l'underscore "_" e il punto "."
       n=$(echo $filename | awk -F \Curve_DTM5_ {'print $2'} | awk -F \. {'print $1'})

       # vedo quanto è grande il numero per aggiungere un numero appropriato di zeri
       if [ $n -lt 9 ]; then
          d="00$n"
       else
          if [ $n -lt 99 ]; then
             d="0$n"
          else
             d="$n"
          fi
       fi

       # quindi crea il nuovo filename
       newfilename="$d.pbf"

       # il comando mv procede con la modfica dei nomi
       mv $filename $newfilename   

    done


#torna nella cartella principale
cd ..


#converte le curve di livello in formato IMG
for infile in $uscitaimg/*.pbf
  do
  MAPNAME=$(basename $infile .pbf)
  echo
  echo "Converto la sezione $MAPNAME in formato IMG"

  java $Xmx -jar $mkgmap --code-page=1252 \
    --mapname=66120$MAPNAME \
    --description="DTM5 Curve di livello" \
    --country-name="Italia" \
    --region-name="Piemonte" \
    --copyright-message="Curve di livello realizzate da $parola, basate sul dataset DTM 2009-2011 Piemonte ICE della Regione Piemonte" \
    --output-dir=$uscitaimg \
    --style-file=stile_garmin/dtm_curve \
    --show-profiles=1 \
    --draw-priority=10 \
    --transparent \
    --license-file=stile_garmin/curve_licenza.txt \
  $infile

done


#cancella i file TYP nella directory stile_garmin/Typ
rm stile_garmin/Typ/*.TYP
rm stile_garmin/Typ/*.typ


# compilo il file typ dal formato testo

     java -jar $mkgmap \
     --family-id=1811 \
     stile_garmin/Typ/${TYPFILE_VERSION}.txt

mv ${TYPFILE_VERSION}.typ stile_garmin/Typ

MASTER_TYPFILE=stile_garmin/Typ/${TYPFILE_VERSION}.typ


# creo le varianti del file master TYP file con le differenze
# cambia solamente il family ID:
for FID in 1811
do
  cp $MASTER_TYPFILE stile_garmin/Typ/$FID.TYP
  $GMT -w -y $FID,1 stile_garmin/Typ/$FID.TYP
done


# ora creo i singoli livelli che comporranno la mappa
# e definisco i singoli file:
DTM5_Curve=$(ls $uscitaimg/66120*.img)


# creo le cartelle di destinazione
mkdir $uscitaimg/etrex
mkdir $uscitaimg/64
mkdir $uscitaimg/mappe


# unisco il file di ogni strato in un file IMG separato per i nuovi disposistivi come ad es. il gps64
$GMT -j -o $uscitaimg/64/Curve.img \
     -f 1811,1 -m "DTM5 Curve di livello" $DTM5_Curve ./stile_garmin/Typ/1811.TYP

    
# gli strati ora vengono uniti in un unico gmapsupp.img per i vecchi dispositivi:
$GMT -j -o $uscitaimg/etrex/gmapsupp.img -m "DTM5-CURVE-GPS (GPS)" \
     $uscitaimg/64/Curve.img


# Ora creo versioni di divisione della mappa per l'utilizzo con Basecamp

# Questo cciclo di mkgmap è usato per fare una mappa panoramica mapset.img
# Che viene utilizzato da Basecamp:
java -jar $mkgmap \
  --series-name="DTM5-CURVE-GPS Map (PC version)" \
  --overview-mapname="mapset"   \
  --country-name="Italia"       \
  --region-name="Piemonte"      \
  --output-dir=$uscitaimg/mappe     \
  --family-id=1811              \
  --draw-priority=10            \
  --family-name="DTM5 Curve di livello"    \
  --product-id=1                \
  $DTM5_Curve                   \
  $MASTER_TYPFILE


# Il file tdb che è stato creato nel processo non funziona
# E non ne abbiamo bisogno, quindi provvedo ad eliminarlo:
rm $uscitaimg/mappe/mapset.tdb


# Facio un gmapsupp.img intermedio, lo utilizziamo per poi dividerlo
# nella creazione dei file per Basecamp:
$GMT -j -o $uscitaimg/mappe/gmapsupp.img \
     -m "DTM5-CURVE-GPS Map (PC version)" \
     -f 1811,1		\
     $DTM5_Curve        \
     $MASTER_TYPFILE


# E divido il file per Basecamp, che genera alcuni file aggiuntivi necessari
# Per l'installazione su Windows, tra cui il file tdb
$GMT -S \
     -f 1811,1 \
     -o $uscitaimg/mappe \
     $uscitaimg/mappe/gmapsupp.img

# cancello il file intermedio gmapsupp.img
rm $uscitaimg/mappe/gmapsupp.img

# E adesso bisogna patchare il file TDB affinchè contenga le corrette informazioni sul copyright
python stile_garmin/tdbfile.py $uscitaimg/mappe/mapset.tdb

#cancella i file
rm osmmap.tdb
rm osmmap.img
rm $uscitaimg/osmmap.tdb
rm $uscitaimg/*.pbf
rm $uscitaimg/*.img


#copia la documentazione nella cartella dei file
cp -r ./Documentazione ./$uscitaimg


#si sposta nella cartella documentazione
cd ./$uscitaimg/Documentazione


#inseriscee il nome e cognome per l'attribuzione della licenza e lo inserisce nel file licenza.txt al posto di "Licenziatario"
sed -i "s/licenziatario/$parola/" Licenza.txt


#converte il file Licenza.txt in PDF
unoconv -f pdf Licenza.txt


#rimuove il file Licenza.txt
rm Licenza.txt


#ritorna nella cartella principale
cd ..
