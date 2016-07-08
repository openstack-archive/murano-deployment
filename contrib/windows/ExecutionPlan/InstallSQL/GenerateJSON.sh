#!/bin/bash

for yaml_file in *.yaml ; do
    [[ -e $yaml_file ]] || break  # handle the case of no *.yaml files
    echo "Converting $yaml_file ..."
    ../ExecutionPlanGenerator.py $yaml_file
done


