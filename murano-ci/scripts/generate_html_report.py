#!/usr/bin/python
from __future__ import with_statement
from jinja2 import FileSystemLoader
from jinja2 import Environment
import lxml.etree as et
import uuid
import sys
import os

if (__name__ == "__main__") and (len(sys.argv) >= 3) and (os.path.exists(sys.argv[1])):
    STATS = {
        'total': 0,
        'success': 0,
        'skip': 0,
        'error': 0,
        'failure': 0,
    }

    REPORT = {}

    tree = et.parse(sys.argv[1])
    root = tree.getroot()

    STATS['total'] = int(root.attrib['tests'])
    STATS['failure'] = int(root.attrib['failures'])
    STATS['error'] = int(root.attrib['errors'])
    STATS['skip'] = int(root.attrib['skip'])
    STATS['success'] = STATS['total'] - STATS['failure'] - STATS['error'] - STATS['skip']

    for case in root:
        class_name = case.attrib['classname']
        test = {
            'name': case.attrib['name'],
            'time': case.attrib['time'],
            'result': 'success',
            'exc_type': None,
            'exc_message': None,
            'traceback': None,
            'output': case.text,
            'uuid': str(uuid.uuid1()),
        }
        for child in case:
            test['exc_type'] = child.attrib['type'] if 'type' in child.attrib.keys() else None
            test['exc_message'] = child.attrib['message'] if 'message' in child.attrib.keys() else None
            test['traceback'] = child.text
            if child.tag == 'error':
                test['result'] = 'error'
            elif child.tag == 'failure':
                test['result'] = 'failure'
            elif child.tag == 'skipped':
                test['result'] = 'skip'

        if class_name not in REPORT.keys():
            REPORT[class_name] = {
                'tests': [],
                'stats': {
                    'total': 0,
                    'failure': 0,
                    'error': 0,
                    'skip': 0,
                    'success': 0,
                },
                'result': 'success',
                'uuid': str(uuid.uuid1()),
            }
        REPORT[class_name]['tests'].append(test)
        REPORT[class_name]['stats']['total'] += 1
        REPORT[class_name]['stats'][test['result']] += 1

    for class_name in REPORT.keys():
        if REPORT[class_name]['stats']['failure'] > 0:
            REPORT[class_name]['result'] = 'failure'
        elif REPORT[class_name]['stats']['error'] > 0:
            REPORT[class_name]['result'] = 'failure'
        elif REPORT[class_name]['stats']['skip'] == REPORT[class_name]['stats']['total']:
            REPORT[class_name]['result'] = 'skip'
        else:
            REPORT[class_name]['result'] = 'success'

    jinja = Environment(
        loader=FileSystemLoader(os.path.join(os.path.dirname(__file__), 'templates'))
    )

    with open(sys.argv[2], 'w') as report_file:
        report_file.write(jinja.get_template(os.path.basename('report.template')).render(
            report=REPORT,
            stats=STATS,
            coverage=os.path.exists(os.path.join(os.environ.get('WORKSPACE'), 'artifacts/coverage'))
        ))
