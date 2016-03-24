..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Troubleshooting
===============

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
