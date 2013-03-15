from distutils.core import setup
import os
import py2exe

build_path = os.path.join(os.environ["PY2EXE_TMPDIR"], "build")
dist_path = os.path.join(os.environ["PY2EXE_TMPDIR"], "dist")

setup(
    console=["flashproxy-client", "flashproxy-reg-email", "flashproxy-reg-http"],
    zipfile="py2exe-flashproxy.zip",
    options={
        "build": { "build_base": build_path },
        "py2exe": {
            "includes": ["M2Crypto"],
            "dist_dir": dist_path
        }
    }
)
