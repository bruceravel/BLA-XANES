..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Installation
============

This package is intended to be installed on a system on which
:demeter:`demeter` (`homepage
<http://bruceravel.github.io/demeter/>`_) is already installed.
Components from :demeter:`demeter` are essential prerequisites for
:program:`Xray::BLA` and :demeter:`metis`.

To install :program:`Xray::BLA` and :demeter:`metis`, do the following:

.. code-block:: bash

   perl Build.PL
   sudo ./Build installdeps  ## (if any dependencies are not met)
   ./Build
   ./Build test
   sudo ./Build install

This will install all the `libraries <../lib/index.html>`_ and put
three programs into your execution path:

#. :program:`bla`, the command line tool

#. :demeter:`metis`, the GUI tool

#. :program:`pilplot`, a tool for quick-and-dirty visualization of the
   tiff files from the Pilatus.


Windows package
---------------

- Install the :demeter:`demeter` installer package,  then
- Install the :demeter:`metis` installer package

Both are download and double-click installers.

.. todo:: URLs and further instuctions
