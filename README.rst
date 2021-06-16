Building and uploading psycopg2 packages
========================================

Note: this repository is no more in use. Starting from 2.9, the procedures to
build psycopg2 packages are part of the `psycopg2 repository`__ itself.

So Long, and Thanks for All the Fish. 🐬🐬🐬

.. __: https://github.com/psycopg/psycopg2

:Linux/OSX: |travis|
:Windows: |appveyor|

.. |travis| image:: https://travis-ci.org/psycopg/psycopg2-wheels.svg?branch=master
    :target: https://travis-ci.org/psycopg/psycopg2-wheels
    :alt: Linux and OSX packages build status

.. |appveyor| image:: https://ci.appveyor.com/api/projects/status/github/psycopg/psycopg2-wheels?branch=master&svg=true
    :target: https://ci.appveyor.com/project/psycopg/psycopg2-wheels/branch/master
    :alt: Windows packages build status

----

This project is used to create binary packages of psycopg2_. It creates:

- Source distribution package
- manylinux_ wheel packages
- OSX wheel packages
- Windows wheel and exe packages

.. _psycopg2: https://psycopg.org/
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

The packages are built on `Travis CI`__ and `AppVeyor CI`__, and uploaded on
https://upload.psycopg.org/

.. __: https://travis-ci.org/psycopg/psycopg2-wheels
.. __: https://ci.appveyor.com/project/psycopg/psycopg2-wheels


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
    username: piro
    password:<whatever>

    [testpypi]
    repository: https://test.pypi.org/legacy/
    username: piro
    password:<whatever>

.. __: https://packaging.python.org/guides/using-testpypi/

Then you can download, sign, and release the packages::

    rsync -arv psycopg-upload:psycopg2-2.7b1 .

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

    python -c "import tests; tests.unittest.main(defaultTest='tests.test_suite')"
