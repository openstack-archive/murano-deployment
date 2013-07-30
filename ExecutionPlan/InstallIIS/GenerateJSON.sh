#!/bin/bash

for yaml_file in $(ls *.yaml) ; do
    echo "Converting $yaml_file ..."
    ../ExecutionPlanGenerator.py $yaml_file
done


