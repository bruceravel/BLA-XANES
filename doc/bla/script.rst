..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


The bla script
==============

Here is an overview of the command line :program:`bla` program and a
summary of which command line switches are recognized by each task:

.. code-block:: text

     bla herfd [cxespvnfqh]  <stub>
     bla rixs  [cxspvnfqh]   <stub>
     bla xes   [cipvnqh]     <stub>
     bla plane [cpvnqh]      <stub>
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
	--noscan           [flag]    do not use scan file
	--xesimage         [integer] specify which image to use for XES
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
                bla point -c=/path/to/config.ini -e=9713 -i=10 Aufoil1

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
