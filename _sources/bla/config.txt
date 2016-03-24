..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The configuration file
======================

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

