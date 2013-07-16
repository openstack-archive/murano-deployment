#!/usr/bin/python

import argparse
import base64
import yaml
import simplejson as json

allowedKeys = ('Scripts', 'Commands', 'RebootOnCompletion')
requiredKeys = ('Scripts', 'Commands')


parser = argparse.ArgumentParser(description='YAML to JSON converter.')
parser.add_argument('filePath', nargs='?', default='ExecutionPlan.yaml')
args = parser.parse_args()


inputFile = open(args.filePath)
yamlData = yaml.safe_load(inputFile)
inputFile.close()


providedKeys = yamlData.keys()

for k in providedKeys:
	if k not in allowedKeys:
		raise Exception("Key '{0}'' is not allowed!".format(k))

for k in requiredKeys:
	if k not in providedKeys:
		raise Exception("Key '{0}'' is required but not found!".format(k))


for i in range(0, len(yamlData['Scripts'])):
	f = open(yamlData['Scripts'][i], 'rb')
	yamlData['Scripts'][i] = base64.b64encode(f.read())
	f.close()


outputFile = open(args.filePath + '.json', 'w+')

json.dump(yamlData, outputFile, indent='  ')
