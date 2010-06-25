#! /bin/bash
DATABASE=sguildb
DB_USER=sguil
DB_PASSWORD=P4ZZW0RD
DAYSTOKEEP=32
MYSQLBIN=/usr/bin/mysql
SGUILDINIT=/etc/init.d/sguil-server

KEEPDAY=`$MYSQLBIN -u$DB_USER -p$DB_PASSWORD -BN -e "SELECT DATE_FORMAT(DATE_SUB(NOW(), INTERVAL $DAYSTOKEEP DAY), '%Y%m%d');" -D $DATABASE`

$SGUILDINIT stop

for TABLEPREFIX in "data" "event" "icmphdr" "sancp" "tcphdr" "udphdr"
do
       $MYSQLBIN -u$DB_USER -p$DB_PASSWORD -BN -e "DROP TABLE $TABLEPREFIX;" -D $DATABASE
       TABLES=(`$MYSQLBIN -u$DB_USER -p$DB_PASSWORD -BN -e "SHOW TABLES LIKE '$TABLEPREFIX%';" -D $DATABASE`)
       for TABLE in "${TABLES[@]}"
       do
               TABLEDAY=`echo "$TABLE" | awk -F_ '{print($3)}'`
               if [ $(($TABLEDAY)) -lt $(($KEEPDAY)) ]
                       then $MYSQLBIN -u$DB_USER -p$DB_PASSWORD -BN -e "DROP TABLE $TABLE;" -D $DATABASE
               fi
       done
done

$SGUILDINIT start

exit 0

