#! /bin/bash

basedir=`dirname $0`
outdir=benchmark-results

mkdir -p $outdir

if [ -z $1 ]; then
  modules=benchmarks/*
else
  modules=benchmarks/$1
fi

for file in $modules; do
  if [ ! -d $file ]; then
    echo "$file is not a directory. Skipping..."
    continue
  fi

  if [ ! -f $file/params.txt ]; then
    echo "$file does not contain 'params.txt' file. Skipping..."
    continue
  fi

  if [ ! -f $file/init.pp ]; then
    echo "$file does not contain 'init.pp' file. Skipping..."
    continue
  fi

  base=$(basename $file)
  params=$(cat $file/params.txt)

  rm -rf $outdir/$base
  # Extract parameters of the module.
  version=$(echo "$params" | grep -oP 'version: [0-9a-z\.]+' |
    sed 's/version: //g')
  modulepath=$(echo "$params" | grep -oP 'modulepath: [a-zA-Z_\-\/.]+' |
    sed 's/modulepath: //g')
  timeout=$(echo "$params" | grep -oP 'timeout: [a-zA-Z]+' | sed 's/timeout: //g')
  modulename=$(echo "$params" | grep -oP 'modulename: [a-zA-Z0-9_-]+' |
    sed 's/modulename: //g')

  base_cmd="$basedir/analyze-modules.sh \
      -t \"$outdir\" \
      -i \"fsmove\" \
      -f \"$version\" \
      -m \"$modulepath\""

  if [ ! -z $timeout ]; then
    base_cmd="$base_cmd -w $timeout"
  fi

  if [ -f $file/pre-script.sh ]; then
    cmd="$base_cmd $modulename -p $file/init.pp -s $file/pre-script.sh"
  else
    cmd="$base_cmd $modulename -p $file/init.pp"
  fi

  eval $cmd
  if [ "$modulename" != "$base" ]; then
    mv $outdir/$modulename $outdir/$base
  fi
done

# Generate csv file
echo "benchmark,total,mor,mn" > benchmark-results/faults.csv
for file in benchmark-results/*; do
  base=$(basename $file)
  if [ "$base" = "faults.csv" ]; then
    continue
  fi
  modulename=$(cat benchmarks/$base/params.txt |
    grep -oP 'modulename: [a-zA-Z0-9_-]+' |
    sed 's/modulename: //g')
  mor=$(cat $file/$modulename.faults | grep -oP 'Number of MOR: ([0-9]+)' |
    sed -r 's/Number of MOR: (.*)/\1/g')
  if [ -z $mor ]; then
    mor=0
  fi
  mn=$(cat $file/$modulename.faults | grep -oP 'Number of MN: ([0-9]+)' |
    sed -r 's/Number of MN: (.*)/\1/g')
  if [ -z $mn ]; then
    mn=0
  fi
  total=$((mn + mor))
  echo "$base,$total,$mor,$mn" >> benchmark-results/faults.csv
done
