#!/usr/bin/python
from __future__ import with_statement
from jinja2 import FileSystemLoader
from jinja2 import Environment
import lxml.etree as et
import uuid
import sys
import os

if not __name__ == "__main__":
    sys.exit(1)
if not len(sys.argv) >= 3:
    sys.exit(1)
if not os.path.exists(sys.argv[1]):
    sys.exit(1)


def get_attr(element, attr):
    return element.attrib[attr] if attr in element.attrib.keys() else None


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
STATS['unsuccess'] = STATS['failure'] + STATS['error'] + STATS['skip']
STATS['success'] = STATS['total'] - STATS['unsuccess']

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
        test['exc_type'] = get_attr(child, 'type')
        test['exc_message'] = get_attr(child, 'message')
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

    TOTAL = REPORT[class_name]['stats']['total']

    for class_name in REPORT.keys():
        if REPORT[class_name]['stats']['failure'] > 0:
            REPORT[class_name]['result'] = 'failure'
        elif REPORT[class_name]['stats']['error'] > 0:
            REPORT[class_name]['result'] = 'failure'
        elif REPORT[class_name]['stats']['skip'] == TOTAL:
            REPORT[class_name]['result'] = 'skip'
        else:
            REPORT[class_name]['result'] = 'success'

    jinja = Environment(
        loader=FileSystemLoader(os.path.join(
            os.path.dirname(__file__), 'templates')
        )
    )

    with open(sys.argv[2], 'w') as report_file:
        report_file.write(jinja.get_template(
            os.path.basename('report.template')
        ).render(
            report=REPORT,
            stats=STATS,
            coverage=os.path.exists(
                os.path.join(os.environ.get('WORKSPACE'), 'artifacts/coverage')
            )
        ))
