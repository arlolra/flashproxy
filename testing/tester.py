#!/usr/bin/python

import os
import sys

for i in range(int(sys.argv[1])):
	print "Running test " + str(i) + "..."
	os.system("cat fac_test_input_" + str(i) + " | ncat 127.0.0.1 9002")

