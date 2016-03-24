.. highlight:: perl


###############
Xray::BLA::Plot
###############

****
NAME
****


Xray::BLA::Plot - A plotting method for BLA-XANES


***********
DESCRIPTION
***********



*******
METHODS
*******



\ ``plot_mask``\ 



\ ``plot_energy_point``\ 



\ ``plot_xanes``\ 



\ ``plot_xes``\ 



\ ``plot_rixs``\ 



\ ``plot_map``\ 



\ ``set_palette``\ 
 
 Change the hue of the image plots.  The choices are grey (the
 default), blue, green, orange, purple, and red.
 
 
 .. code-block:: perl
 
    $spectrum -> set_palette($color);
 
 
 An unknown color is ignored.
 



************
DEPENDENCIES
************


`PDL::Graphics::Gnuplot <http://search.cpan.org/search?query=PDL%3a%3aGraphics%3a%3aGnuplot&mode=module>`_


********************
BUGS AND LIMITATIONS
********************


Please report problems as issues at the github site
`https://github.com/bruceravel/BLA-XANES <https://github.com/bruceravel/BLA-XANES>`_

Patches are welcome.


******
AUTHOR
******


Bruce Ravel (bravel AT bnl DOT gov)

`http://github.com/bruceravel/BLA-XANES <http://github.com/bruceravel/BLA-XANES>`_

gnuplot-colorbrewer is written and maintained by Anna Schneider
<annarschneider AT gmail DOT com> and released under the Apache
License 2.0.  ColorBrewer is a project of Cynthia Brewer, Mark
Harrower, and The Pennsylvania State University.


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2006-2014,2016 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See perlgpl.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

