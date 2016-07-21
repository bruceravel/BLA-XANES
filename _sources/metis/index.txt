..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


The Metis program
=================

The :demeter:`metis` program is modal, providing slightly different
functionality for HERFD, XES, and RXES data sets.  At the command
line, it is invoked with a command line argument to put it into the
correct mode.


To start :demeter:`metis` in XES mode, provide the ``xes`` argument:

.. code-block:: shell

   metis xes


.. figure:: ../_images/metis_startup.png
   :target: ../_images/metis_startup.png
   :align: center

   :demeter:`metis`, at startup, invoked in XES mode

Similarly, to begin :demeter:`metis` in ``hrfd`` or ``rxes`` mode, do

.. code-block:: shell

   metis herfd
   metis rxes

The state of your data analysis is maintained separately for the three
experimental modes.  Along with providing functionality specific to
the three experimental data sets, you can recover parameters
appropriate to your analysis of that data.

.. toctree::
   :maxdepth: 1

   files.rst
   mask.rst
   data.rst
   config.rst


