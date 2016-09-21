#!/bin/python

import subprocess

return_code = subprocess.call("echo Installation Complete > test", shell=True)
