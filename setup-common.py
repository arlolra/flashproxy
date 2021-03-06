#!/usr/bin/env python
"""Setup file for the flashproxy-common python module.

To build/install a self-contained binary distribution of flashproxy-client
(which integrates this module within it), see Makefile.
"""
# Note to future developers:
#
# We place flashproxy-common in the same directory as flashproxy-client for
# convenience, so that it's possible to run the client programs directly from
# a source checkout without needing to set PYTHONPATH. This works OK currently
# because flashproxy-client does not contain python modules, only programs, and
# therefore doesn't conflict with the flashproxy-common module.
#
# If we ever need to have a python module specific to flashproxy-client, the
# natural thing would be to add a setup.py for it. That is the reason why this
# file is called setup-common.py instead. However, there are still issues that
# arise from having two setup*.py files in the same directory, which is an
# unfortunate limitation of python's setuptools.
#
# See discussion on #6810 for more details.

import os
import subprocess
import sys

# Prevent setuptools from trying to download dependencies.
# https://trac.torproject.org/projects/tor/ticket/10847
os.environ["http_proxy"] = "127.0.0.1:9"
os.environ["https_proxy"] = "127.0.0.1:9"

from setuptools import setup, find_packages

p = subprocess.Popen(["sh", "version.sh"], stdout=subprocess.PIPE)
output, _ = p.communicate()
assert p.poll() == 0
version = output.strip()

setup(
    name = "flashproxy-common",
    author = "dcf",
    author_email = "dcf@torproject.org",
    description = ("Common code for flashproxy"),
    license = "BSD",
    keywords = ['tor', 'flashproxy'],

    packages = find_packages(exclude=['*.test']),
    test_suite='flashproxy.test',

    version = version,

    install_requires = [
        'setuptools',
        'M2Crypto',
        ],
)
