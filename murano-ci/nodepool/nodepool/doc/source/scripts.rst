.. _scripts:

Node Prep Scripts
=================

Nodepool requires the specification of a script directory
(`script-dir`) in its configuration.  When Nodepool starts a virtual
machine for the purpose of creating a snapshot image, all of the files
within this directory will be copied to the virtual machine so they
are available for use by the setup script.

At various points in the image and node creation processes, these
scripts may be invoked by nodepool.  See :ref:`configuration` for
details.

Any environment variables present in the nodepool daemon environment
that begin with ``NODEPOOL_`` will be set in the calling environment
for the script.  This is useful during testing to alter script
behavior, for instance, to add a local ssh key that would not
otherwise be set in production.

Setup script
------------

Each provider can specify a setup script with `setup`, and that script is
expected to exist in `script_dir`. If it is found, it will be run during image
creation. When the script is invoked, the instance hostname will be passed in
as the first parameter.


Ready script
------------

Each label can specify a ready script with `ready-script`.  This script can be
used to perform any last minute changes to a node after it has been launched
but before it is put in the READY state to receive jobs.  In particular, it
can read the files in /etc/nodepool to perform multi-node related setup.

Those files include:

**/etc/nodepool/role**
  Either the string ``primary`` or ``sub`` indicating whether this
  node is the primary (the node added to the target and which will run
  the job), or a sub-node.
**/etc/nodepool/primary_node**
  The IP address of the primary node.
**/etc/nodepool/sub_nodes**
  The IP addresses of the sub nodes, one on each line.
**/etc/nodepool/id_rsa**
  An OpenSSH private key generated specifically for this node group.
**/etc/nodepool/id_rsa.pub**
  The corresponding public key.

