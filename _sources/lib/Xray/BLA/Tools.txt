.. highlight:: perl


################
Xray::BLA::Tools
################

****
NAME
****


Xray::BLA::Tools - A role with tools and conveniences for BLA


*******
VERSION
*******


See Xray::BLA


*******
METHODS
*******



\ ``file_template``\ 
 
 Construct a file name from BLA object attributes using a simple
 %-sign substitution scheme:
 
 
 .. code-block:: perl
 
     %s : stub
     %e : emission energy
     %i : incident energy
     %t : tiffcounter
     %T : padded, 3-digit energy index
     %c : energy index counter
     %% : literal %
 
 
 As an example:
 
 
 .. code-block:: perl
 
     $bla->file_template('%s_elastic_%e_%t.tif')
 
 
 might evaluate to \ *Aufoil1_elastic_9711_00001.tif*\ .
 


\ ``howlong``\ 
 
 Report on a time span in human readable terms.
 
 
 .. code-block:: perl
 
      my $start = DateTime->now( time_zone => 'floating' );
      ##
      ## do stuff...
      ##
      print $spectrum->howlong($start, $text);
 
 
 The first argument is a DateTime object created at the beginning of a
 lengthy chore.  The second argument is text that will be reported in
 the return string, as in "$text took NN seconds".
 


\ ``randomstring``\ 
 
 Return a random string of a specified length, used to make temporary
 files and folders.
 
 
 .. code-block:: perl
 
     my $string = $spectrum->randomstring(6);
 
 
 The default is a 6-character string.
 


\ ``is_windows``\ , \ ``is_osx``\ 
 
 Return true is the operating system is Windows or OSX.  This is a
 simple heuristic based on \ ``$^O``\  (see http://perldoc.perl.org/perlvar.html);
 



******
AUTHOR
******


Bruce Ravel (bravel AT bnl DOT gov)

`http://github.com/bruceravel/BLA-XANES <http://github.com/bruceravel/BLA-XANES>`_


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See `perlgpl <http://perldoc.perl.org/perlgpl.html>`_.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

