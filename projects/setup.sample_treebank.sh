#!/usr/bin/env bash

echo "======================================="
echo "STARTING setup-sample_treebank"
gstart=`date +%s`

set -e

data_dir="/opt/pmltq/data/pdt20_sample"
run_dir="/opt/pmltq/run"

if [ ! -d "$data_dir" ]; then
  echo "Looks like PML-TQ is not installed" >&2
  exit 1
fi

# source stuff
source /home/vagrant/perl5/perlbrew/etc/bashrc
export PATH="/opt/tred:$PATH"

if [ ! -d "$data_dir/sql_dump.postgres" ]; then
  $data_dir/bin/convert_to_db.sh
  $data_dir/bin/create_db.sh
  $data_dir/bin/load_to_db.sh
fi

$run_dir/run.sh --stop
$run_dir/run.sh --start

gend=`date +%s`
echo "ENDING took $((end-start)) seconds"
echo "======================================="