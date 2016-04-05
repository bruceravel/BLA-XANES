.. highlight:: perl


################
Xray::BLA::Image
################

****
NAME
****


Xray::BLA::Image - Role for importing signed 32 bit TIFF files


*******
VERSION
*******


See Xray::BLA


*******
METHODS
*******



\ ``Read``\ 
 
 Read a signed 32 bit image from the Pilatus into a PDL data structure
 and set the \ ``columns``\  and \ ``rows``\  attributes of the Xray::BLA object.
 
 
 .. code-block:: perl
 
      my $image = $self->Read($pilatus_image);
 
 
 A million thanks to Chris Marshall for his help on the problem of
 reading signed 32 bit tiff files!  The old PDL-general archives from
 before the move to SourceForge doen't seem to be available, Here is my
 question and Chris' answer from the Wayback Machine:
 `https://web.archive.org/web/20141030084128/http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008623.html <https://web.archive.org/web/20141030084128/http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008623.html>`_
 


\ ``fetch_metadata``\ 
 
 Fetch metadata about the Piltus image from the tiff headers.  Return
 an anonymous hash containing \ ``Model``\ , \ ``DateTime``\ , \ ``BitsPerSample``\ ,
 \ ``width``\ , and \ ``height``\ .
 
 
 .. code-block:: perl
 
      my $hash = $self->fetch_metadata($pilatus_image);
 
 



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

