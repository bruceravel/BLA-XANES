..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Output
======

-  The output of the ``herfd`` task is a data file containing the HERFD
   spectrum at the specified emission energy and, if requested, gif
   images with the mask.

   At each energy point, the HERFD signal is computed from the Pilatus
   image using the mask created as described above. The counts on each
   pixel lying within the illuminated portion of the mask are summed.
   This sum is the HERFD signal at that incident energy.

   A column data file is written containing the energy and several
   scalars from the original measurement and a column containing the
   HERFD signal. This file can be imported directly into Athena.

-  The output of the ``rixs`` task is the same as for the ``herfd``
   script at each emission energy.

   .. todo:: Athena .prj output from :program:`bla` program

-  The output of the ``xes`` task is a data file containing the XES
   spectrum from that incident energy with the signal from each emission
   energy weighted by the number of illuminated pixels in that mask.

-  The output of the ``map`` task is a data file in a `simple
   format <http://gnuplot.info/docs_4.2/gnuplot.html#x1-33600045.1.2>`__
   which can be read by gnuplot and a gnuplot script for displaying the
   data. The resulting image will plot a map of detector column vs
   detector row with the color axis showing energy. Gif files for the
   masks at each emission energy are also written.

-  The output of the ``mask`` task is a single gif file containing the
   mask for the specified emission energy.

-  The output of the ``point`` task is the HERFD value extracted from a
   specified BLA image for a specified emission energy. The value is
   printed to STDOUT. If files containing the BLA image or the emission
   mask do not exist or if any other problem is encountered, 0 is
   printed to STDOUT.

On Windows, tiff files are written rather than gif files.

The ``herfd``, ``rixs``, ``xes``, and ``map`` tasks are intended for
post-processing of a full data set.

The ``mask`` and ``point`` tasks are intended for inlining in the data
acquisition process. The ``mask`` task should be run after measuring the
elastic images at the emission energy and before measuring the HERFD
data. The ``mask`` task takes about 10 seconds.

The ``point`` task is intended for generating the HERFD value at a
specific emission energy during the scan. This value can be used for
plotting or storing to the output data file. The ``point`` task takes
less than 1 second.

Saving masks as image files
---------------------------

In order to save mask images, you may need to install some additional
software on your computer.  PDL uses the NetPBM package for image
format manipulation.  On Ubuntu, the package is called ``netpbm`` and
is likely already installed.  This is not installed by the Demeter
installer for Windows, so you have to install it separately.  Download
and install `the NetPBM Windows installer
<http://gnuwin32.sourceforge.net/packages/netpbm.htm>`__.

Note where the binaries get installed.  You must add that location to
the execution path.  This can be done at the Windows command prompt by

.. code-block:: bash

     set PATH=%PATH%;C:\GnuWin32\bin

substituting ``C:\GnuWin32\bin`` with the location on your computer.

Without NetPBM, an invocation of the :program:`bla` program with the
``-s`` flag will not run to completion.

Animations
----------

Using ImageMagick on the output masks:

.. code-block:: bash

    convert -layers OptimizePlus -delay 5x100 *mask.gif -loop 0 mask_animation.gif

.. todo:: Write animations using PDL

XDI Output
----------

All ASCII column data is written in the XDI format.  This is
particularly handy for the RIXS function.  If XDI metadata is provided,
then the ``BLA.pixel_ratio`` metadatum will be written to the output
file.  This number is computed from the number of pixels illuminated in
the mask at each emission energy.  The pixel ratio for an emission
energy is the number of pixels from the emission energy with the
largest number of illuminated pixels divided by the number of
illuminated pixels at that energy.

The pixel ratio can be used to normalize the mu(E) data from each
emission energy. The concept is that the normalized mu(E) data are an
approximation of what they would be if each emission energy was equally
represented on the face of the detector.

The version of Athena based on Demeter will be able to use these values
as importance or plot multiplier values if the ``Xray::XDI`` module is
available.

XDI metadata about the beamline and sample can be supplied using the
``-x`` switch for the :program:`bla` program, the ``BLAXDIINI``
environment variable, or in the ``[files]`` block of the
configuration file.  Here is an example

.. code-block:: bash

   [column]
   1 = energy eV
   2 = mu
   3 = i0
   4 = it
   5 = ifl
   6 = ir
   7 = herfd
   8 = integration seconds
   9 = ring mA

   [xescolumn]
   1 = energy eV
   2 = xes
   3 = npixels
   4 = raw

   [beamline]
   name = APS 10ID (MRCAT)
   collimation = none
   focusing = HR mirror in the vertical, KB mirror in the horizontal
   harmonic_rejection = Pt coated mirror

   [facility]
   energy = 7.00 GeV
   source = APS Undulator A
   
   [mono]
   name = Si (111)
   d_spacing = 3.13553

   [detector]
   i0 = 1cm N2
   herfd = bent Laue analyzer, Si(660), Pilatus 100K


