.. highlight:: perl


#############
Xray::BLA::IO
#############

****
NAME
****


Xray::BLA::IO - Role containing input and output operations


*******
VERSION
*******


See Xray::BLA


*******
METHODS
*******



\ ``mask_file``\ 
 
 Compute the name of an output file from the parameters of the
 calculation.
 
 
 .. code-block:: perl
 
     my $fname = $self->mask_file($type, $imagetype);
 
 
 \ ``$type``\  is one of \ ``mask``\ , \ ``shield``\ , \ ``previousshield``\ ,
 \ ``rixsplane``\ , \ ``anim``\ , \ ``map``\ , \ ``maskmap``\ , or an integer denoting a
 file in a sequence.
 
 \ ``imagetype``\  is one of "gif", "tif", or "png" and specifies the output
 image format.
 


\ ``xdi_out``\ 
 
 Write HERFD data to an XDI file.  Return the name of the computed
 output file.  The arguments are the name of the ini file with XDI
 metadata and a reference to the hash containing the calculated HERFD
 data.
 
 
 .. code-block:: perl
 
     $outfile = $self->xdi_out($xdiini, \@data);
 
 


\ ``xdi_xes``\ 
 
 Write XES data to an XDI file.  Return the name of the computed output
 file.  The arguments are the name of the ini file with XDI metadata,
 the name of the XES image file, and a reference to the hash containing
 the calculated XES data.
 
 
 .. code-block:: perl
 
     my $outfile = $self->xdi_xes($xdiini, $xesimage, \@xes);
 
 


\ ``energy_map``\ 
 
 Write the results of the \ ``map``\  task to an output data file.  The
 arguments control screen output and the creation (not currently
 working) of an animation showing how the energy map was made.
 
 
 .. code-block:: perl
 
     my $spectrum -> energy_map(verbose => 1, animate=>0);
 
 


\ ``gnuplot_map``\ 
 
 Write gnuplot commands to use the data written by \ ``energy_map``\ .
 
 
 .. code-block:: perl
 
     open(my $GP, '>', 'splot.gp');
     my $gp = $self->gnuplot_map;
     print $GP $gp;
     close $GP;
 
 



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

