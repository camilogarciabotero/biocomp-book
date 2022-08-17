#! /usr/bin/env bash

motif="TAAA(T|A)(.)(T|A)(G|A)(.)(C|A)GGT|ACC(T|G)(.)(T|C)(T|A)(.)(T|A)TTTA"

for f in $(ls $1); do
  if [ -s ${1}/${f} ]; then
      motifnumber=$(tr -d '\n' < ${1}/${f} | egrep -o $motif | wc -l)
      header=$(head -n 1 ${1}/${f})
      echo -e "There are $motifnumber motifs in $header"
  else
      echo "$f is empty"
  fi
done
