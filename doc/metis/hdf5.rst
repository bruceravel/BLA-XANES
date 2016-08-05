..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


The HDF5 save file
==================

The top level structure of the save file looks like the diagram below.
The root has a single attribute which identifies the creator of the
HDF5 file. This is likely to be "Metis", although if we ever get
around to packing the images into an HDF5 file at the beamline, then
the creator attribute might be something else.

The :quoted:`elastic` and :quoted:`images` groups contain the actual
content of the various images made during the measurement.  The
:quoted:`elastic` group contains the sequence of elastic images, while
the :quoted:`images` groups contains the set of resonant or
non-resonant XES images.

The other groups are a way of organizing the many parameters of the
:demeter:`metis` analysis project, including the various attributes of
the `Xray::BLA object <../lib/Xray/BLA.html>`_, `the XDI metadata
<https://github.com/XraySpectroscopy/XAS-Data-Interchange>`_, and the
contents of the scan file.

The :quoted:`application` group contains debugging information |nd|
mostly version numbers of major packages used by :demeter:`metis`, a
string identifying the computer platform used to create the file, and
a timestamp.


.. blockdiag::
   :desctable:

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     root -> name;

     root -> application, configuration, elastic, images, metadata, scan;
     application   [description = "Version numbers, timestamp"];
     configuration [description = "Xray::BLA attributes"];
     elastic       [description = "collection of elastic images"];
     images        [description = "collection of XES images"];
     metadata      [description = "XDI metadata"];
     scan          [description = "information from scan file"];
     name          [description = "name of program creating file"];

     group {
       label = "attribute";
       name;
     }
     group {
       label = "groups";
       color = "#7777FF";
       application; configuration; elastic; images; metadata; scan;
     }
   }


The elastic group
-----------------

The elastic group contains the sequence of elastic images, each image
in a subgroup in the group.  The name of the data set is the energy
portion of the filename of the measured tiff image.  In the case of
one of the Nb K\ |beta|\ :sub:`2,4` measurements seen throughout this
manual, the filename of an elastic image might be something like
:file:`NbF5_Kb2_elastic_189555_0001.tif`.  That image was measured
with the incident energy at 18955.5 eV.  The decimal was removed to
make the filename.  The name of the group containing this image is
``189555``.

The subgroups each contain three datasets.  These datasets contain the
original image (``image``), the shield if used (``shield``), and the
final mask (``mask``).

Each subgroup has two attributes associated with it, called ``energy``
and ``filename``.  In the case of dataset ``189555``, the ``energy``
attribute is set to the energy value, 18955.5 eV, and the ``filename``
is set to the fully resolved filename of the tiff file.


.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     A [label = "elastic group"];
     B [label = "energy label", stacked];
     CP [style = "dotted", label = "195x487 arrays of shorts", shape = "note"];
     DP [style = "dotted", label = "195x487 arrays of bytes", shape = "note"];
     C [label = "image"];
     D [label = "shield"];
     E [label = "mask"];

     A -> B;
     B -> C;
     B -> D;
     B -> E;
     C -- CP [style = dotted];
     D -- DP [style = dotted];
     E -- DP [style = dotted];

     group {
       label = "groups";
       color = "#7777FF";
       B;
     }

     group {
       label = "datasets";
       color = "#FF3377";
       C, D, E;
     }


     BE [label = "energy"];
     BF [label = "file name"];
     B -> BE;
     B -> BF;

     group {
       label = "attributes";
       BE, BF;
     }

   }


The images group
----------------

The images group contains all of the resonant or non-resonant XES
images made as part of the measurement.  In ``XES`` mode, this will
typically be some number of repetitions made at an energy well above
the edge.  In ``HERFD`` mode, this will be sequence of images made at
each point in the XANES scan.  In ``RXES`` and ``Mask`` modes, this
group will be empty.

In ``HERFD`` mode, each dataset in this group will have an ``energy``
attribute giving it's energy in the XANES scan.  In ``XES`` mode, the
``energy`` attribute is absent.  The ``filename`` attribute is set to
the fully resolved filename of the tiff file.  The ``skip`` attribute
is a flag which tells :demeter:`metis` whether to exclude an image
from the analysis.  For example, in ``XES`` mode, setting this to a
false value for an image would exclude it from a merge of the
resulting XES spectra.  In ``HERFD`` mode it would be excluded from
the XANES spectrum (not unlike deglitching).


.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     A [label = "image group"];
     B [label = "image", stacked];
     BP [style = "dotted", label = "195x487 arrays of shorts", shape = "note"];

     A -> B;
     B -- BP [style = dotted];

     group {
       label = "datasets";
       color = "#FF3377";
       B;
     }

     BE [label = "(energy)"];
     BF [label = "file name"];
     BS [label = "skip"];
     B -> BE;
     B -> BF;
     B -> BS;

     group {
       label = "attributes";
       BE, BF, BS;
     }
   }


The configuration group
-----------------------

This group has no datasets, just a lot of attributes for capturing
much of the structure of the `Xray::BLA object
<../lib/Xray/BLA.html>`_ in the context of :demeter:`metis`, this
group captures the values of most of the controls on `the Files
<files.html>`_ and `Mask pages <mask.html>`_ as well as all of the
contents of `the Configuration page <config.html>`_.

.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     A [label = "configuration group"];
     B [label = "mode"];
     MODE [style = "dotted", label = "(XES|HERFD|RXES|MASK)", shape = "note"];
     C [label = "files, folders, templates", stacked];
     D [label = "mask building parameters", stacked];
     E [label = "configuration parameters", stacked];
     F [label = "plotting parameters", stacked];
     G [label = "Mask recipe"];
     GP [style = "dotted", label = "list of strings", shape = "note"];
     H [label = "Mask spots list"];
     HP [style = "dotted", label = "list of strings", shape = "note"];

     A -> B;
     B -- MODE [style = "dotted"];
     A -> C;
     A -> D;
     A -> E;
     A -> G;
     A -> H;
     G -- GP [style = "dotted"];
     H -- HP [style = "dotted"];

     group {
       label = "attributes";
       B, C, D, E, F;
     }
     group {
       label = "datasets";
       color = "#FF3377";
       G, H;
     }

   }

Use the ``configuration/mode`` attribute to determine what
:demeter:`metis` mode this HDF5 file was created in.


The metadata group
------------------

This group has no datasets, just a bunch of groups for the XDI
metadata families.  Each subgroup has a lot of attributes which
capture everything from `the XDI page <xdi.html>`_.

There is a subgroup for each of the `defined semantic groupings
<https://github.com/XraySpectroscopy/XAS-Data-Interchange/blob/master/specification/dictionary.md#name-spaces>`_
used in an XES measurement.  There is another subgroup called
``Xescolumns`` which is used when exporting a column data file
containing an XES spectrum.  Any other metadata families defined by
the user will be exported into their own subgroups.

.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     A [label = "metadata group"];
     B [label = "Beamline"];
     C [label = "Column"];
     D [label = "Detector"];
     E [label = "Facility"];
     F [label = "Mono"];
     G [label = "Xescolumn"];
     H [label = "", shape = "dots"];
     I [label = "etc.", stacked];

     A -> B;
     A -> C;
     A -> D;
     A -> E;
     A -> F;
     A -> G;
     A -> H [style = 'none'];
     A -> I;

     group {
       label = "subgroups";
       color = "#7777FF";
       B, C, D, E, F, G, H, I;
     }

     Z [label = "metadata items", stacked];
     B -> Z;
     C -> Z;
     D -> Z;
     E -> Z;
     F -> Z;
     G -> Z;
     H -> Z [style = 'none'];
     I -> Z;

     group {
       label = "attributes";
       Z;
     }

   }

.. todo:: ``BLA`` and ``Pilatus`` metadata families


The scan group
--------------

The scan file is simply slurped into the HDF5 file and stored as the
``contents`` attribute of the scan group.

.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     A [label = "scan group"];
     B [label = "contents"];
     BP [label = "slurped-in scan file", style=dotted, shape=note];
     C [label = "file"];
     CP [label = "path to scan file", style=dotted, shape=note];
     D [label = "temporary"];
     DP [label = "scan file temporary location", style=dotted, shape=note];

     A -> B;
     A -> C;
     A -> D;
     B -- BP [style=dotted];
     C -- CP [style=dotted];
     D -- DP [style=dotted];

     group {
       label = "attributes";
       B, C, D;
     }

   }

The ``file`` attribute contains the full path to the slurped-in file.
The ``temporary`` attribute holds the full path to the location where
:demeter:`metis` writes out the stash file temporarily for use in
``HERFD`` and ``RXES`` modes.  That changes between instances of the
program.



The application group
---------------------

This groups contains attributes explaining the state of the program,
including a timestamp, the platform on which it was run, and the
version numbers of many of the software components.  This is mostly
useful for diagnostic purposes.

.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     A [label = "application group"];
     B [label = "timestamp"];
     BP [style = "dotted", label = "HDF5 file creation time", shape = "note"];
     C [label = "platform"];
     CP [style = "dotted", label = "(linux|windows|mac)", shape = "note"];
     D [label = "perl version"];
     DP [style = "dotted", label = "perl's $] variable", shape = "note"];
     E [label = "Xray::BLA version"];
     F [label = "Demeter version"];
     G [label = "perl module versions", stacked];

     A -> B;
     B -- BP [style = "dotted"];
     A -> C;
     C -- CP [style = "dotted"];
     A -> D;
     D -- DP [style = "dotted"];
     A -> E;
     A -> F;
     A -> G;

     group {
       label = "attributes";
       B, C, D, E, F, G;
     }

   }
