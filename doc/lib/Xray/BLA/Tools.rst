.. highlight:: perl


################
Xray::BLA::Tools
################

****
NAME
****


Xray::BLA::Tools - Tools and conveniences for BLA


*******
VERSION
*******


See `Xray::BLA <http://search.cpan.org/search?query=Xray%3a%3aBLA&mode=module>`_


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
     %c : energy index counter
     %% : literal %
 
 
 As an example:
 
 
 .. code-block:: perl
 
     $bla->file_template('%s_elastic_%e_%t.tif')
 
 
 might evaluate to \ *Aufoil1_elastic_9711_00001.tif*\ .
 



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
under the same terms as Perl itself. See perlgpl.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

