#!/usr/bin/python

import argparse
import base64
import yaml
import simplejson as json


parser = argparse.ArgumentParser(description='YAML to JSON converter.')
parser.add_argument('filePath', nargs='?', default='ExecutionPlan.yaml')
args = parser.parse_args()


inputFile = open(args.filePath)
yamlData = yaml.safe_load(inputFile)
inputFile.close()


for i in range(0, len(yamlData['Scripts'])):
	f = open(yamlData['Scripts'][i], 'rb')
	yamlData['Scripts'][i] = base64.b64encode(f.read())
	f.close()


outputFile = open(args.filePath + '.json', 'w+')

json.dump(yamlData, outputFile, indent='  ')
