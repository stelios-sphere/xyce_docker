# Xyce 7.8

This repository contains a dockerized version of Xyce 


## How to built
```
./build.bat
```
## How to Use (in dev) 
```
cd example
docker run -i -t -v $(pwd)/:/opt  xyce:v1.0 /bin/bash
cd /opt
/usr/local/bin/Xyce cmos.cir
```
## Examples and Templates 
 - coming soon 

## Authors:
This software is written by spheresemi 
