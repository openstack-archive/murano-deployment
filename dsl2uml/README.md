# MuranoPL to UML converter

This folder contains scripts (currently only one) to generate UML graphs based on MuranoPL manifests.

## Installation

1. Copy **plantuml.py** to **meta** folder under MuranoPL directory.

2. Download **plantuml.jar** from http://plantuml.sourceforge.net/ and copy it to the folder ablve.

3. Generate UML graph using the command below:

```
    ./plantuml.py
```

## Usage

```
   ./plantuml.py [--no-namespaces] [--parents-only] [CLASS_FQDN]
```

* **--no-namespaces** - disables automatic classes grouping

* **--parents-only** - generate graph using only parent-child dependencies

* **CLASS_FQDN** - MuranoPL class FQDN

