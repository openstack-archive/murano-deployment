Execution Plan
==============

Execution Plan is a sequence of actions that should be run on an instance in order to configure it.

Execution Plan contains at least one step, and may reboot the instance.

An Exectution Plan definition file may contain following sections:
* PowerShell functions that are passed to the instance as part of Execution Plan
* At least one execution step
* Conditional reboot statement

In order to simplify the process of Execution Plan creation, a simple SDL was introduced.

SDL's statements:
* include <file with PowerShell functions>
* call <PowerShell function name> [<argument name>=<argument value> [...]]
* reboot <condition>
* out <output file name>

SEE ALSO
========
* `Murano <http://murano.mirantis.com>`__

