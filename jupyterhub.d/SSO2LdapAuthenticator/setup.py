#!/usr/bin/env python
# coding: utf-8

#-----------------------------------------------------------------------------
# Minimal Python version sanity check (from IPython/Jupyterhub)
#-----------------------------------------------------------------------------

from __future__ import print_function

import os
import sys

v = sys.version_info
if v[:2] < (3,3):
    error = "ERROR: Jupyter Hub requires Python version 3.3 or above."
    print(error, file=sys.stderr)
    sys.exit(1)

if os.name in ('nt', 'dos'):
    error = "ERROR: Windows is not supported"
    print(error, file=sys.stderr)

# At least we're on the python version we need, move on.

#from setuptools import setup
from distutils.core import setup

pjoin = os.path.join
here = os.path.abspath(os.path.dirname(__file__))

# Get the current package version.
version_ns = {}
with open(pjoin(here, 'version.py')) as f:
    exec(f.read(), {}, version_ns)

setup_args = dict(
    name                = 'ssotoldap_authenticator',
    packages            = ['ssotoldap_authenticator'],
    version             = version_ns['__version__'],
    description         = """Web to Unix Authenticator: Authenticate users with a Web identifier (e.g., via Shibboleth) and map them to Unix accounts.""",
    long_description    = "",
    author              = "Enrico Bocchi",
    author_email        = "enrico.bocchi@cern.ch",
    url                 = "https://swan.web.cern.ch",
    license             = "GPLv3",
    platforms           = "Linux, Mac OS X",
    keywords            = ['Interactive', 'Interpreter', 'Shell', 'Web'],
    classifiers         = [
        'Intended Audience :: Developers',
        'Intended Audience :: System Administrators',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: GNU General Public License v3 (GPLv3)',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
    ],
)

# setuptools requirements
if 'setuptools' in sys.modules:
    setup_args['install_requires'] = install_requires = []
    with open('requirements.txt') as f:
        for line in f.readlines():
            req = line.strip()
            if not req or req.startswith(('-e', '#')):
                continue
            install_requires.append(req)


def main():
    setup(**setup_args)

if __name__ == '__main__':
    main()
