#!/usr/bin/env python

import sys

from setuptools import setup, find_packages

setup(
    name = "flashproxy-common",
    author = "dcf",
    author_email = "dcf@torproject.org",
    description = ("Common code for flashproxy"),
    license = "BSD",
    keywords = ['tor', 'flashproxy'],

    packages = find_packages(),

    version = "1.3",

    install_requires = [
        'setuptools',
        ],
)
