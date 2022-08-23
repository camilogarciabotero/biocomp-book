#!/usr/bin/bash

## EcoRV digests the motif GATATC into GAT^ATC

fragments=$(tail -n +2 $1 | tr --delete '\n' | sed 's/GATATC/GAT\nATC/g')

for line in $fragments; do
    echo $line | wc -c
done
