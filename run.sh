#!/bin/bash
cd db
redis-server | {
	L=""
	while [[ $L != *"server is now ready"* ]]
	do
		echo $L
		read L
	done
	echo $L
	cd ..
	node app
} &