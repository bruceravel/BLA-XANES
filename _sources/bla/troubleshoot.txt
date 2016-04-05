..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Troubleshooting
===============

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


Error checking
--------------

The library is not particularly robust in terms of flagging problems.
You should not expect particularly useful error messages if the folders
in the configuration file are not correct or if you give an emission
energy value that was not measured as an elastic image. In those cases,
the program will almost certainly fail with some kind of stack trace,
but probably not with an immediately useful error message. To say this
another way, it's up to you to do file management sensibly.


PDL and Gnuplot
---------------

Apply ``share/PGG/PGG.patch`` to
``/usr/local/share/perl/5.20.2/PDL/Graphics/Gnuplot.pm`` to suppress the
``Reading ras files from sequential devices not supported`` warning when
using the qt terminal. This is a qt issue and appears to be of no
consequence.

Around line 3116 of ``PDL::Graphics::Gnuplot``, add the following line:

.. code-block:: perl

    $optionsWarnings =- s/^Reading ras files from sequential devices not supported.*$//mg;
    $optionsWarnings = '' if($optionsWarnings =- m/^\s+$/s);

Similar near lines 3256, 3301.

Another solution is to replace ``print STDERR`` with ``carp`` at line
3116 and elsewhere.  If that is done, then Metis is instrumented to
handle terminal-related chatter a bit more gracefully.
