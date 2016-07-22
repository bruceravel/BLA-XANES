..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The bla program
===============

All measurements require a set of Pilatus images taken at energies
around the fluorescence energy. These are used to make a mask which
identifies which pixels contain signal related to specific emission
energies.



A HERFD measurement set also consists of

- A column data file with columns of energy and scalars from the
  measurement.

- One Pilatus image for each energy point in the XANES scan containing
  the HERFD signal at that point.


An XES measurement set also consists of 

- One or more Pilatus images taken above the absorption edge as a
  measure of the non-resonant XES.

A RIXS measurement consists of

- A set of Pilatus images taken at energies around the onset of the
  absorption edge.  This may be the same set of images as the elastic
  images.

This software uses perl, `Moose
<https://metacpan.org/release/Moose>`__, and `PDL
<http://pdl.perl.org>`__ to process the images into a high resolution
XANES spectrum.  The GUI, called :demeter:`metis`, uses WxWidgets and
its perl bindings.  See `Xray::BLA::Image <lib/Xray/BLA/Image.html>`__
for how to import the signed 32 bit tiff images from the Pilatus
directly into PDL.


Usage
-----

``bla``, found in the ``bin/`` folder, is a wrapper script around the
bent Laue processing tasks:

#. ``herfd``: make a single HERFD spectrum at a specific emission energy

#. ``xes``: compute the emission spectrum for a specific incident energy

#. ``rixs``: generate a sequence of HERFD spectra at a sequence of
   emission energies, i.e. make an XAS-like RIXS plane

#. ``plane``: generate a sequence of XES spectra at a sequence of
   incidence energies and concatenate them into a single output file,
   i.e. make an XES-like RIXS plane

#. ``map``: convert a series of elastic images to an energy vs. pixel
   map

#. ``mask``: compute the mask file for a specific emission energy

#. ``point``: convert a specified BLA image to its HERFD value for a
   specified emission energy


Contents
--------


.. toctree::
   :maxdepth: 2

   install.rst
   script.rst
   env.rst
   output.rst
   config.rst
   mask.rst
   tasks.rst
   troubleshoot.rst
