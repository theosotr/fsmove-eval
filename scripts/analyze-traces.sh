#! /bin/bash

counter=1
for file in $1/*; do
  module=$(basename $file)
  if [ "$module" = "faults.csv" ]; then
    continue
  fi
  echo "Processing $counter: $module..."
    fsmove -mode offline \
      -print-stats \
      -catalog $file/$module.json \
      -trace-file $file/$module.strace > $file/$module.faults
    stat $file/$module.strace |
    grep -oP 'Size: \K([0-9]+)' > $file/$module.size
    cat $file/$module.faults |
    grep -oP 'Analysis time: \K([0-9\.]+)' >> $file/$module.times
  counter=$((counter + 1))
done

# Generate csv file
echo "benchmark,total,mor,mn" > $1/faults.csv
for file in $1/*; do
  base=$(basename $file)
  if [ "$base" = "faults.csv" ]; then
    continue
  fi
  mor=$(cat $file/$base.faults | grep -oP 'Number of MOR: ([0-9]+)' |
    sed -r 's/Number of MOR: (.*)/\1/g')
  if [ -z $mor ]; then
    mor=0
  fi
  mn=$(cat $file/$base.faults | grep -oP 'Number of MN: ([0-9]+)' |
    sed -r 's/Number of MN: (.*)/\1/g')
  if [ -z $mn ]; then
    mn=0
  fi
  total=$((mn + mor))
  echo "$base,$total,$mor,$mn" >> $1/faults.csv
done
sudo chown -R fsmove:fsmove $1
