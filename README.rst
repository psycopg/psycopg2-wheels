Building and uploading psycopg2 wheels
======================================

.. image:: https://travis-ci.org/psycopg/psycopg2-wheels.svg?branch=master
    :target: https://travis-ci.org/psycopg/psycopg2-wheels
    :alt: Build Status

This project is used to create binary packages of psycopg2_.

Currently it only supports building source package and manylinux_ wheels. In
the future it should allow building `OSX packages too`__. Maybe windows?

.. _psycopg2: http://initd.org/psycopg/
.. _manylinux: https://github.com/pypa/manylinux
.. __: https://github.com/psycopg/psycopg2/issues/479


Creating new wheels
===================

When a new psycopg2 release is ready, just upload the submodule to the release
tag and push::

    cd psycopg2
    git checkout 2_7_BETA_1
    cd ..
    git add psycopg2
    git commit -m "Building packages for psycopg2 2.7 beta 1"
    git push

The packages are `built on Travis CI`__ and uploaded__ on the initd.org server.

.. __: https://travis-ci.org/psycopg/psycopg2-wheels
.. __: http://initd.org/psycopg/upload/


Uploading to PyPI
=================

After the packages are uploaded they can be signed and uploaded on PyPI_, e.g.
using twine_. Testing releases can be uploaded on `Test PyPI`_.

.. _PyPI: https://testpypi.python.org/pypi/psycopg2
.. _twine: https://pypi.python.org/pypi/twine
.. _Test PyPI: https://pypi.python.org/pypi/psycopg2

You must have your ``~/.pypirc`` file configured__, e.g. ::

    [distutils]
    index-servers =
        pypi
        testpypi

    [pypi]
    repository: http://www.python.org/pypi
    username: piro
    password:<whatever>

    [testpypi]
    repository: https://testpypi.python.org/pypi
    username: piro
    password:<whatever>

.. __: https://wiki.python.org/moin/TestPyPI

Then you can download, sign, and upload the packages::

    rsync -arv initd.org:/home/upload/upload/psycopg2-2.7b1 .

    # For a test release
    twine upload -s -r testpypi psycopg2-2.7b1/*

    # For a final release
    twine upload -s -r pypi psycopg2-2.7/*

You can test what just uploaded with::

    # Make sure you have a version that understand wheels
    pip install -U pip

    # For a test release
    pip install -i https://testpypi.python.org/pypi --no-cache-dir psycopg2==2.7b1

    # For a final release
    pip install --no-cache-dir psycopg2

    python -c "import psycopg2; print(psycopg2.__version__)"
    # 2.7b1 (dt dec pq3 ext lo64)

    python -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
