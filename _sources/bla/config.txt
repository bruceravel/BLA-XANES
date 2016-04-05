..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The configuration file
======================

The configuration file is in the Windows-style ini format using a
here-doc style extension for multi-line parameter values.  Here is an
example:

.. code-block:: bash

    [measure]
    emission           = 9703 9705 9707 9709 9711 9713 9715 9717 9719
    scanfolder         = /home/bruce/Data/NIST/10ID/2011.12/scans
    tiffolder          = /home/bruce/Data/NIST/10ID/2011.12/tiffs
    outfolder          = /home/bruce/Data/NIST/10ID/2011.12/processed
    element            = Au
    line               = La1
    tiffcounter        = 0001
    energycounterwidth = 4
    imagescale         = 40
    outimage           = gif

    [files]
    scan    = %s.001
    elastic = %s_elastic_%e_%t.tif
    image   = %s_%c.tif

    [spots]
    xrange = 58 334
    spots=<<END
    9705       289  67  3
    9707-9713  164 128  3
    9715+       61 193 10
    END

    [steps]
    steps = <<END
    bad 400 weak 0
    gaussian 2.4
    polyfill
    END

This configuration file can sit anywhere on disk and **must** be
specified at the command line or via the ``BLACONFIG`` environment
variable when using the ``bla`` script. I would recommend that you put
it in the current work directory wherever you are working on your data.
You may wish to keep multiple configuration files around for different
experiments, different edges, different samples, etc.


The ``[measure]`` block
-----------------------

**Emission energies**

  In the ``[measure]`` section, the ``emission`` item, which is not used
  by the ``herfd`` function, contains the list of emission energies at
  which to generate HERFD spectra.  The next three items are the locations
  of the scan files, the image files, and the output files. 

  The ``emission`` line can use a more concise syntax if the sequence of
  elastic energies was measured on a uniform grid. The following are
  equivalent:

  .. code-block:: text

     emission = 9703 9705 9707 9709 9711 9713 9715 9717 9719

     emission = 9703 to 9719 by 2


  The amount of white space does not matter in the concise format, but
  the words ``to`` and ``by`` are required.

  If the ``emission`` line has only a single energy, then you can omit the
  ``-e`` flag when using the ``herfd``, ``mask``, or ``point`` tasks.

**element and line**

  ``element`` and ``line`` are used to identify the emission line being
  measured.  This information can sometimes be determined from energy
  range of the input data, but not reliably.  The identification of the
  emission line is used when labeling plots, making the map in the
  ``map`` task, and to set certain defaults in :demeter:`metis`.

**tiffcounter and energycounterwidth**

  ``tiffcounter`` and ``energycounterwidth`` are used along with the
  templates in the ``[files]`` block to construct file names for
  sequences of images.

**imagescale**

  ``imagescale`` is used to set the color scale of surface plots when
  displaying Pilatus images and masks.

**outimage**

  ``outimage`` sets the format for output image files.  The sensible
  choices are gif, tiff, and png.



The ``[files]`` block
---------------------

The ``[files]`` section defines several mini-templates for specifying
file names. In this example, the elastic images are stored on disk with
names like ``Aufoil1_elastic_9711_00001.tif``. The "elastic" template is
``%s_elastic_%e_%t.tif``. The ``%s`` is replaced by the stub, ``%e`` and
``%t`` are replaced by the elastic energy and the tiff counter (used to
construct file names on the camera). The tags used in the template
system are:

::

    %s : stub
    %e : emission energy
    %i : incident energy
    %t : tiffcounter
    %T : padded three-digit energy index
    %c : energy index counter
    %% : literal %

``scan`` specifies the pattern of the scan file name.  ``elastic``
specifies the pattern of the elastic images.  ``image`` specifies the
pattern of the images used to make the HERFD or RIXS data.

The ``[spots]`` block
---------------------

The ``[spots]`` block is used to manually exclude regions of the
elastic image from mask creation.  Particularly bright, spurious,
illuminated regions of the elastic image can survive filtering steps
in a mask creation recipe, such as the Gaussian blur or the lonely
pixels filter.  Such spurious pixels will certainly add spurious
signal to a HERFD or XES measurement.  They can also serious impact
the polyfill recipe step.  If other algorithmic steps fail to remove
such points, regions can be specified by hand.

**xrange**

  The ``xrange`` specifies the region of the detector that sees signal
  from the elastic measurements.  This can be determined by examining
  the lowest and highest energies in the elastic sequence and noting the
  pixels in the width direction of the detector containing the elastic
  signal.  Pixels outside of this range are set to 0.

**spots**

  Individual spots |nd| due to diffraction peaks or other effects |nd|
  that fall within the range on the detector subtended by the sequence
  of elastic energies can be removed by specifying their locations and
  the elastic energies at which they appear.

  The syntax of this section is somewhat fussy. It is essential that
  there are no spaces after either instance of the word ``END``. Other
  than that, white space is not important, but spelling is.

  An individual line contains four items, the energy at which the spot
  appears, the x and y coordinates, and a radius.  All pixels within the
  specified radius of the x-y coordinate will be set to 0.

  The energy at which to do this manual spot removal has some syntax.
  The simplest, as in the first line, specifies the energy at which to
  do the manual removal.  In this example, only the image at 9705 eV has
  a spot at (289,67).

  In the second example, a spot at (164,128) appears in the images from
  9707 eV to 9713 eV, inclusive.

  In the third example, a spot appears at (61,193) from 9715 eV to the
  end of the energy sequence.

Take care not to make the radii too small |nd| you want to remove the
entire spurious spot.  But if the spot is close to the elastic
scattering, making the radius tool large will undesirably remove some
of the elastic signal.

The ``[steps]`` block
---------------------

The ``[steps]`` section is used to define the `recipe used to make the
mask <mask.html>`_ at any emission energy. The syntax of this section
is somewhat fussy. It is essential that there are no spaces after
either instance of the word ``END``. Other than that, white space is
not important, but spelling is.


