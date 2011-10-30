#!/bin/sh

for n in $(seq 1 50); do
	./throughput.sh -n $n
done
