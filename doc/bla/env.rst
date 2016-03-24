..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Environment variables
=====================

Specifying the configuration file
---------------------------------

Use of the ``-c`` flag can be avoided by setting the ``BLACONFIG``
environment variable. The following are equivalent:

.. code-block:: bash

      bla herfd -c=/path/to/config.ini -e=9713 Aufoil1

      export BLACONFIG=/path/to/config.ini
      bla herfd -e=9713 Aufoil1

Specifying the emission energy
------------------------------

Use of the ``-e`` flag can be avoided by setting the ``BLAENERGY``
environment variable. The following are equivalent:

.. code-block:: bash

      bla herfd -c=/path/to/config.ini -e=9713 Aufoil1

      export BLAENERGY=9713
      bla herfd -c=/path/to/config.ini Aufoil1

You can also avoid using the ``-e`` flag by setting a single energy in
the ``emission`` line of the configuration file. (Of course, having only
a single energy in that list will hamper the ``rixs``, ``map``, and
``xes`` tasks....)

Specifying metadata
-------------------

Use of the ``-x`` flag can be avoided by setting the ``BLAXDIINI``
environment variable. The following are equivalent:

.. code-block:: bash

      bla herfd -c=/path/to/config.ini -x /path/to/xdi.ini -e=9713 Aufoil1

      export BLAXDIINI=/path/to/xdi.ini
      bla herfd -c=/path/to/config.ini -e 9713 Aufoil1

The ini file for the XDI metadata can also be specified in the
``[files]`` block of the main configuration file.

Each environment variable is overridden by its respective command line
switch.
