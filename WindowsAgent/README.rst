Glazier Windows Agent README
============================

Glazier Windows Agent is a component that does all the work on a target node.
Currently only Windows nodes are supported.

Agent embeddes PowerShell engine which is the only execution engine.


Interaction with Conductor
--------------------------

Interaction with Conductor (receiving execution plans and submitting results) is performed via RabbitMQ server.

Agent receives execution plan, caches it and executes. Reboots during execution are allowed.

When execution completes, all output from PowerShell engine is passed back via the RabbitMQ server to the Conductor.


Agent Configuration
-------------------

All necessary configuration is performed during instance creation process. No manual actions needed.


SEE ALSO
--------
* `Glazier <http://glazier.mirantis.com>`__
