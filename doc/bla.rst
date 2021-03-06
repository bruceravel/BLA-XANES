..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The bla program
===============

Synopsis
--------

A measurement set consists of

-  A column data file with columns of energy and scalars from the
   measurement.

-  One Pilatus image for each energy point in the XANES scan containing
   the HERFD signal at that point.

-  A set of Pilatus images taken at energies around the fluorescence
   energy. These are used to make a mask which identifies which pixels
   contain signal related to specific emission energies.

This software uses perl, `Moose
<https://metacpan.org/release/Moose>`__, and `PDL
<http://pdl.perl.org>`__ to process the images into a high resolution
XANES spectrum. The GUI, called :demeter:`metis`, uses WxWidgets and
its perl bindings. See `Xray::BLA::Image <lib/Xray/BLA/Image.html>`__
for how to import the signed 32 bit tiff images directly into PDL.

Installation
------------

To install, do the following:

.. code-block:: bash

         perl Build.PL
         sudo ./Build installdeps  ## (if any dependencies are not met)
         ./Build
         ./Build test
         sudo ./Build install

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

The bla script
~~~~~~~~~~~~~~

.. code-block:: text

     bla herfd [cxespvnfqh]  <stub>
     bla rixs  [cxspvnfqh]   <stub>
     bla xes   [cipvnqh]     <stub>
     bla map   [crpvnqh]     <stub>
     bla mask  [csvnfqh]     <stub>
     bla point [ceih]        <stub>

        --config   | -c    [string]  configuration file (required)
        --energy   | -e    [integer] emission energy (required for herfd/point tasks)
        --incident | -i    [integer] data point at which compute HERFD (required for point/xes task)
        --xdiini   | -x    [string]  XDI configuration file
	--noscan           [flag]    true if no scan file is present
        --reuse    | -r    [flag]    reuse mask files for energy map if in outfolder
        --save     | -s    [flag]    save mask as gif
        --plot     | -p    [flag]    plot data (herfd/rixs/map/xes tasks)
        --verbose  | -v    [flag]    write progress messages
        --nocolor  | -n    [flag]    turn off color coding of screen output
        --format   | -f    [string]  output static image format, gif or tif
        --quiet    | -q    [flag]    suppress progress messages
        --help     | -h    [flag]    write this message and exit

The ``bla`` script assumes that scan files and image files have
related names. In this example, the ``<stub>`` is ``Aufoil1``, then
scan file is called ``Aufoil1.001``, and the image files are called
``Aufoil1_NNNNN.tif``. The ``NNNNN`` in the image file name indicates
the data point and is reflected in one of the columns of the scan
file. If your data do not follow these patterns, this script will
fail. File locations are specified in the configuration file.

.. code-block:: text

     examples:  bla herfd -c=/path/to/config.ini -e=9713 Aufoil1
                bla rixs  -c=/path/to/config.ini Aufoil1
                bla plane -c=/path/to/config.ini Aufoil1
                bla map   -c=/path/to/config.ini Aufoil1
                bla xes   -c=/path/to/config.ini -i=11970 Aufoil1
                bla mask  -c=/path/to/config.ini -e=9713 Aufoil1
                bla point -c=/path/to/config.ini -e=9713 -p=10 Aufoil1

Here, :quoted:`Aufoil1` is the stub, i.e. the basename of the scan and image
files, and the ``-c`` and ``-e`` command line options are demonstrated.

The ``-i`` flag, used by ``point`` and ``xes`` can take either an
integer, indicating the index of the data point, or a number, indicating
the incident energy of the datapoint. So the following may be
equivalent:

.. code-block:: text

         bla point -c=/path/to/config.ini -e=9713 -i=69 Aufoil1
         bla point -c=/path/to/config.ini -e=9713 -i=12000 Aufoil1

For the ``point`` task, the ``-i`` flag **must** be specified. For the
``xes`` task, if the ``-i`` flag is omited, the midpoint of the scan (in
index, not in energy) will be used.

Options that are not used by a function (for example ``-e`` for ``rixs``
or ``map``, or ``-i`` for any task other than ``point`` or ``xes``) will
be silently ignored.

``-c`` is required for all functions unless the ``BLACONFIG``
environment variable is set.

The ``-r`` flag is a time-saver for the ``rixs``, ``map``, and ``xes``
tasks. When present, this flag tells the program to reuse any mask
images or scan files found in the output folder. This is safe so long as
the mask creation parameters in the configuration file have not been
changed.

Since the ``point`` task returns a number intended for use during data
acquisition, verbosity is turned off regardless of the command line
switches. Use the ``-q`` flag if you want to suppress screen messages
during the ``mask`` task. Saving is turned on for the ``mask`` task
regardless of the command line switches.

``-p`` will cause a plot to be made using Gnuplot before exiting for the
``herfd``, ``xes``, and ``map`` tasks. The program and plot will exit
when you hit return. For the ``rixs`` task, the most recent HERFD
spectrum will be plotted before immediately going on to the next
emmission eenrgy. The HERFD plots are quite crude, without axis labels
or other ornaments.

Environment variables
~~~~~~~~~~~~~~~~~~~~~

Use of the ``-c`` flag can be avoided by setting the ``BLACONFIG``
environment variable. The following are equivalent:

.. code-block:: bash

      bla herfd -c=/path/to/config.ini -e=9713 Aufoil1

      export BLACONFIG=/path/to/config.ini
      bla herfd -e=9713 Aufoil1

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

Use of the ``-x`` flag can be avoided by setting the ``BLAXDIINI``
environment variable. The following are equivalent:

.. code-block:: bash

      bla herfd -c=/path/to/config.ini -x /path/to/xdi.ini -e=9713 Aufoil1

      export BLAXDIINI=/path/to/xdi.ini
      bla herfd -c=/path/to/config.ini -e 9713 Aufoil1

Each environment variable is overridden by its respective command line
switch.

Output
~~~~~~

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

The configuration file
~~~~~~~~~~~~~~~~~~~~~~

The configuration file is in the Windows-style ini format. Here is an
example:

.. code-block:: ini

    [measure]
    emission   = 9703 9705 9707 9709 9711 9713 9715 9717 9719
    scanfolder = /home/bruce/Data/NIST/10ID/2011.12/scans
    tiffolder  = /home/bruce/Data/NIST/10ID/2011.12/tiffs
    outfolder  = /home/bruce/Data/NIST/10ID/2011.12/processed
    element    = Au
    line       = La1

    [files]
    scan       = %s.001
    elastic    = %s_elastic_%e_%t.tif
    image      = %s_%c.tif

    [steps]
    steps = <<END
    bad 400 weak 0
    multiply by 5
    areal mean radius 2
    bad 400 weak 2
    lonely 3
    social 2
    END

`Here is an example configuration
file. <https://github.com/bruceravel/BLA-XANES/blob/master/share/config.ini>`__

The ``emission`` can use a more concise syntax if the sequence of
elastic energies was measured on a uniform grid. The following are
equivalent:

.. code-block:: text

   emission = 9703 9705 9707 9709 9711 9713 9715 9717 9719

   emission = 9703 to 9719 by 2


White space does not matter, but the words ``to`` and ``by`` are
required.

If the ``emission`` line has only a single energy, then you can omit the
``-e`` flag when using the ``herfd``, ``mask``, or ``point`` tasks.

This configuration file can sit anywhere on disk and **must** be
specified at the command line or via the ``BLACONFIG`` environment
variable when using the ``bla`` script. I would recommend that you put
it in the current work directory wherever you are working on your data.
You may wish to keep multiple configuration files around for different
experiments, different edges, different samples, etc.

In the ``[measure]`` section, the ``emission`` item, which is not used
by the ``herfd`` function, contains the list of emission energies at
which to generate HERFD spectra. The next three items are the locations
of the scan files, the image files, and the output files. The last two
items are used to properly scale the color palette of the energy map by
positively identifying the emission line measured.

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
    %c : energy index counter
    %% : literal %

The ``[steps]`` section is used to define the sequence of operations
used to make the mask at any emission energy. The syntax of this section
is somewhat fussy. It is essential that there are no spaces after either
instance of the word ``END``. Other than that, white space is not
important, but spelling is.

The possible steps to mask creation are:

#. Bad and weak pixel removal. The syntax is ``bad # weak #``. The first
   number indicates the value above which a pixel is assumed to be a bad
   pixel. The second number is the value below which a pixel is
   considered weak. Both bad and weak pixels are removed from the mask.

#. Multiply emission image by an overall constant. The syntax is
   ``multiply by #`` where the number is the constant scaling factor.

#. Apply an areal median or mean to each pixel. The syntax is
   ``areal (median|mean) radius #``. The number defines the size of the
   square considered around each pixel. A value of 1 means a 3x3 square,
   a value of 2 means a 5x5 square. The value of each pixel is set to
   either the mean or the median value of the pixels in the square.

#. Remove all the lonely pixels. A lonely pixel is one which is
   illuminated but is not surrounded by enough illuminated pixels. The
   syntax is ``lonely #``. The number defines how many illuminated
   pixels are required for a pixel not to be considered lonely.

#. Include all social pixels. A social pixel is one which is not
   illuminated but is surrounded by enough illuminated pixels. The
   syntax is ``social #``. The number defines how many of the
   surrounding pixels must be illuminated for the pixel to be turned on.

#. Use the energy map computed by the ``map`` task. The syntax is
   ``map #`` where the number is the width in eV about the emission
   energy. Any pixels with a value of ``<emission> +/- <width>`` will be
   included in the mask. Note that it makes no sense to use this step
   with any step other than the bad/weak step, which should precede this
   step.

#. Use the entire image. The syntax is ``entire image``. This step just
   sets all the pixels in the mask to 1 so that the entire image is used
   to compute the energy point. Note that it makes no sense to use this
   step with any step other than the bad/weak step, which should precede
   this step.

The steps can come in any order and can be repeated. At the end of the
final step, the illuminated pixels in the mask will be set to a value of
1 so that the final mask can be used as an AND mask to create the HERFD
spectra.

Care is taken at the end to remove bad pixels that might have been
restored by the areal or social pixel steps.

Error checking
~~~~~~~~~~~~~~

The library is not particularly robust in terms of flagging problems.
You should not expect particularly useful error messages if the folders
in the configuration file are not correct or if you give an emission
energy value that was not measured as an elastic image. In those cases,
the program will almost certainly fail with some kind of stack trace,
but probably not with an immediately useful error message. To say this
another way, it's up to you to do file management sensibly.

Saving masks as image files
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to save mask images, you may need to install some additional
software on your computer. PDL uses the NetPBM package for image format
manipulation. On Ubuntu, the package is called ``netpbm`` and is likely
already installed. This is not installed by the Demeter installer for
Windows, so you have to install it separately. Download and install `the
NetPBM Windows
installer <http://gnuwin32.sourceforge.net/packages/netpbm.htm>`__.

Note where the binaries get installed. You must add that location to the
execution path. This can be done at the Windows command prompt by

.. code-block:: bash

     set PATH=%PATH%;C:\GnuWin32\bin

substituting ``C:\GnuWin32\bin`` with the location on your computer.

Without NetPBM, an invocation of the bla script with the ``-s`` flags
will not run to completion.

Animations
~~~~~~~~~~

Using ImageMagick on the output masks:

.. code-block:: bash

    convert -layers OptimizePlus -delay 5x100 *mask.gif -loop 0 mask_animation.gif

XDI Output
~~~~~~~~~~

When a configuration file containing XDI metadata is used, the output
files will be written in XDI format. This is particularly handy for the
RIXS function. If XDI metadata is provided, then the ``BLA.pixel_ratio``
metadatum will be written to the output file. This number is computed
from the number of pixels illuminated in the mask at each emission
energy. The pixel ratio for an emission energy is the number of pixels
from the emission energy with the largest number of illuminated pixels
divided by the number of illuminated pixels at that energy.

The pixel ratio can be used to normalize the mu(E) data from each
emission energy. The concept is that the normalized mu(E) data are an
approximation of what they would be if each emission energy was equally
represented on the face of the detector.

The version of Athena based on Demeter will be able to use these values
as importance or plot multiplier values if the ``Xray::XDI`` module is
available.

PDL and Gnuplot
~~~~~~~~~~~~~~~

Apply ``share/PGG/PGG.patch`` to
``/usr/local/share/perl/5.20.2/PDL/Graphics/Gnuplot.pm`` to suppress the
``Reading ras files from sequential devices not supported`` warning when
using the qt terminal. This is a qt issue and appears to be of no
consequence.

Around line 3116 of ``PDL::Graphics::Gnuplot``, add the following line:

.. code-block:: perl

    $optionsWarnings =~ s/^Reading ras files from sequential devices not supported.*$//mg;
    $optionsWarnings = '' if($optionsWarnings =~ m/^\s+$/s);

Similar near lines 3256, 3301.
