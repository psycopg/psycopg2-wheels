Building and uploading psycopg2 packages
========================================

:Linux/OSX: |travis|
:Windows: |appveyor|

.. |travis| image:: https://travis-ci.org/psycopg/psycopg2-wheels.svg?branch=master
    :target: https://travis-ci.org/psycopg/psycopg2-wheels
    :alt: Linux and OSX packages build status

.. |appveyor| image:: https://ci.appveyor.com/api/projects/status/github/psycopg/psycopg2-wheels?svg=true
    :target: https://ci.appveyor.com/project/psycopg/psycopg2-wheels
    :alt: Windows packages build status

This project is used to create binary packages of psycopg2_. It creates:

- Source distribution package
- manylinux_ wheel packages
- OSX wheel packages
- Windows wheel and exe packages

.. _psycopg2: http://initd.org/psycopg/
.. _manylinux: https://github.com/pypa/manylinux


Creating new packages
=====================

When a new psycopg2 release is ready, just upload the submodule to the release
tag and push::

    cd psycopg2
    git checkout 2_7_BETA_1
    cd ..
    git add psycopg2
    git commit -m "Building packages for psycopg2 2.7 beta 1"
    git push

The packages are built on `Travis CI`__ and `AppVeyor CI`__, and uploaded__ on
the initd.org server.

.. __: https://travis-ci.org/psycopg/psycopg2-wheels
.. __: https://ci.appveyor.com/project/psycopg/psycopg2-appveyor
.. __: http://initd.org/psycopg/upload/


Uploading to PyPI
=================

.. note::

    These are just minimal instruction to create test packages. To make
    a new public release please follow the instructions in
    `psycopg2/doc/release.rst`__.

    .. __: https://github.com/psycopg/psycopg2/blob/master/doc/release.rst

After the packages are uploaded they can be signed and uploaded on PyPI_, e.g.
using twine_. Testing releases can be uploaded on `Test PyPI`_.

.. _PyPI: https://pypi.python.org/pypi/psycopg2
.. _twine: https://pypi.python.org/pypi/twine
.. _Test PyPI: https://testpypi.python.org/pypi/psycopg2

You must have your ``~/.pypirc`` file configured__, e.g. ::

    [distutils]
    index-servers =
        pypi
        testpypi

    [pypi]
    repository: https://pypi.python.org/pypi/
    username: piro
    password:<whatever>

    [testpypi]
    repository: https://testpypi.python.org/pypi
    username: piro
    password:<whatever>

.. __: https://wiki.python.org/moin/TestPyPI

Then you can download, sign, and release the packages::

    rsync -arv initd.org:/home/upload/upload/psycopg2-2.7b1 .

    # For a test release
    twine upload -s -r testpypi psycopg2-2.7b1/*


You can test what just uploaded with::

    # Make sure you have a version that understand wheels
    pip install -U pip

    # Install from testpypi
    pip install -i https://testpypi.python.org/pypi --no-cache-dir psycopg2==2.7b1

    # Check the version installed is the correct one and test if it works ok.
    python -c "import psycopg2; print(psycopg2.__version__)"
    # 2.7b1 (dt dec pq3 ext lo64)

    python -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
