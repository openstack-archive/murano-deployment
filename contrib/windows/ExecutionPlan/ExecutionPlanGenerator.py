#!/usr/bin/python

#  Licensed under the Apache License, Version 2.0 (the "License"); you may
#  not use this file except in compliance with the License. You may obtain
#  a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.

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
