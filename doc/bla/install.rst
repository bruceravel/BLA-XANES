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

.. Note:: The requisite package ``Graphics::Gnuplot::Palettes`` is not
   on CPAN and will not be installed at the ``Build installdeps``
   step.  Download this package from
   https://github.com/bruceravel/Graphics-Gnuplot-Palettes and follow
   its build instructions.


Windows package
---------------

- Install the :demeter:`demeter` installer package,  then
- Install the :demeter:`metis` installer package

Both are download and double-click installers.

.. todo:: URLs and further instuctions

Building the document
---------------------

Building the :demeter:`metis` document requires at least version 1.3
of `Sphinx <http://www.sphinx-doc.org/en/stable/>`_.  If you have
python already installed on your computer, you can do:

.. code-block:: bash

   sudo pip install sphinx

Note that Ubuntu only recently began distributing 1.3.  If you have an
earlier version, you will need to upgrade by doing

.. code-block:: bash

   sudo pip install --upgrade sphinx

You can check the version of Sphinx with this command

.. code-block:: bash

   sphinx-build --version


You will then need a number of sphinx extensions:

.. code-block:: bash

   sudo pip install sphinxcontrib-blockdiag
   sudo pip install pybtex
   sudo pip install sphinxcontrib-bibtex

To build the html document, do the following

.. code-block:: bash

   cd doc/
   make html

This will use :program:`sphinx-build` to convert the source code into
html pages.  The html pages will be placed in :file:`_build/html/`.
This folder is a self-contained package.  The html/ folder can be
copied and placed somewhere else.  The web pages can be accessed with
full functionality in any location.

You might want to edit the :file:`doc/conf.py` document to change the
``blockdiag_fontpath`` parameter to point to a TrueType font that
exists on your computer.  The default font used in the block diagrams
in the `HDF5 save file <../metis/hdf5.html>`_ section is rather ugly.

Building the document to a PDF file is not yet supported.
