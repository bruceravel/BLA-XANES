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

Developing :demeter:`metis` uncovered some shortcomings of
`PDL::Graphics::Gnuplot
<https://metacpan.org/pod/PDL::Graphics::Gnuplot>`_.  I made a `pull
request <https://github.com/drzowie/PDL-Graphics-Gnuplot/pull/49>`_
that addressed most of my concerns.  Eventually, the modified version
of P::G::G will be a prerequisite.

In a nutshell, the problem is that :program:`Gnuplot` puts up a lot of
chatter on STDOUT and STDERR.  P::G::G has trouble recognizing when
that chatter indicates a real problem and when it is something benign
that can be ignored.  For example, when using the qt terminal in 
:program:`Gnuplot`, this line gets written frequently to the screen
and often triggers an exception:

.. code-block:: text

   Reading ras files from sequential devices not supported

It is, however, a completely harmless warning.

In any case, :demeter:`metis` is instrumented to handle that and a few
other common warnings without any reaction.  Other unexpected warnings
will be displayed in a Wx dialog box rather than sent to the screen or
triggering an exception.  That provides enough feedback to investigate
the problem without causing the program to terminate.

