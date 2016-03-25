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
 
 Make a surface plot of the current state of the elastic image.
 
 
 .. code-block:: perl
 
    $spectrum -> plot_mask;
 
 
 This is plotted in the same orientation as ImageJ (i.e. (0,0) is in
 the \ *upper*\ , left corner.  That's psychotic, but what can you do...?
 


\ ``plot_energy_point``\ 
 
 Make a surface plot of a raw image.
 
 
 .. code-block:: perl
 
    $spectrum -> plot_energy_point;
 
 
 This is plotted in the same orientation as ImageJ (i.e. (0,0) is in
 the \ *upper*\ , left corner.
 


\ ``plot_xanes``\ 
 
 Make a plot of the computed HERFD.
 
 
 .. code-block:: perl
 
    $spectrum -> plot_xanes(title=>$title, pause=>0, mue=>$self->{mue}->GetValue);
 
 
 The arguments are the title of the plot, whether to use
 Xray::BLA::Pause, and whether to overplot the HERFD with conventional
 XANES (if it exists),
 


\ ``plot_xes``\ 
 
 Make a plot of the computed XES.
 
 
 .. code-block:: perl
 
    $spectrum -> plot_xanes(pause=>0, incident=>$incident, xes=>$self->{xesdata});
 
 
 The arguments are whether to use Xray::BLA::Pause, aninteger
 identifying the incident energy, and a list reference containing the
 XES data.
 


\ ``plot_rixs``\ 
 
 Make a surface plot of the RIXS plane.
 


\ ``plot_map``\ 
 
 Make a surface plot of the energy map.
 


\ ``set_palette``\ 
 
 Change the hue of the image plots.  The choices are grey (the
 default), blue, green, orange, purple, and red.
 
 
 .. code-block:: perl
 
    $spectrum -> set_palette($color);
 
 
 An unknown color is ignored.  If you do
 
 
 .. code-block:: perl
 
    $spectrum -> set_palette("surprise");
 
 
 then one of the hues will be chosen at random.  Ooooh!  Fun!
 



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

