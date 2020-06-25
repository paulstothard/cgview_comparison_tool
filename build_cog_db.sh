#!/bin/bash -e

if [ ! -d ./cog_db ]; then
    mkdir ./cog_db
fi

if [ -f ./cog_db/.complete ]; then
  echo "COG BLAST database already created"
  echo "Remove './cog_db/.complete' to create again"
  exit 0
fi

echo "Copying and extracting COG files"
cp ./lib/scripts/assign_cogs/db/whog.gz ./cog_db
cp ./lib/scripts/assign_cogs/db/myva.gz ./cog_db

gunzip ./cog_db/whog.gz
gunzip ./cog_db/myva.gz

echo "Preparing COG BLAST database"
formatdb -p T -i ./cog_db/myva -o T -l ./cog_db/formatdb.log

echo "COG BLAST database created"
touch ./cog_db/.complete