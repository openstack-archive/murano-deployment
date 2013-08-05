# AlwaysOn Availability Group workflow

## Create Active Directory domain

## Install Failover Cluster prerequisites

Execute **FailoverClusterPrerequisites.yaml** execution plan on each node of the cluster.

## Install and configure Failover Cluster

Choose one node from Failover Cluster nodes. This will be "Failover Cluster Master" node.

Execute **FailoverCluster.yaml** execution plan on 'Failover Cluster Master' node.

## Configure environment for SQL Server installation

Choose one node from Failover Cluster. This will be "AG Primary" node. It might be the same node as "Faiover Cluster Master" node.

'primaryNode' parameter in execution plans refers to "AG Primary" node.

Execute **ConfigureEnvironmentForAOAG.yaml** on each node of the cluster.

## Install SQL Server

Execute **InstallSqlServerForAOAG.yaml** on each node of the cluster.

## Initialize AlwaysOn on SQL Server instancesces

Execute **InitializeAlwaysOn.yaml** on each node of the cluster.

## Initialize AOAG Primary replica

Execute **InitializeAOAGPrimaryReplica.yaml** on each node of the cluster.

The underlying scripts will check 'primaryNode' parameter and execute the script if it is equal to instance's name.

## Initialize AOAG Secondary replicas

Execute **InitializeAOAGSecondaryReplica.yaml** on each node of the cluster.

The underlying scripts will check 'primaryNode' parameter and execute the script if it is NOT equal to instance's name.
