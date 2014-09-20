#!/usr/bin/python
"""Setup file for the flashproxy-common python module."""
from distutils.core import setup
import os
import py2exe

# Prevent setuptools from trying to download dependencies.
# https://trac.torproject.org/projects/tor/ticket/10847
os.environ["http_proxy"] = "127.0.0.1:9"
os.environ["https_proxy"] = "127.0.0.1:9"

build_path = os.path.join(os.environ["PY2EXE_TMPDIR"], "build")
dist_path = os.path.join(os.environ["PY2EXE_TMPDIR"], "dist")

setup(
    console=["flashproxy-client", "flashproxy-reg-appspot", "flashproxy-reg-email", "flashproxy-reg-http", "flashproxy-reg-url"],
    zipfile="py2exe-flashproxy.zip",
    options={
        "build": { "build_base": build_path },
        "py2exe": {
            "includes": ["M2Crypto"],
            "dist_dir": dist_path
        }
    }
)
