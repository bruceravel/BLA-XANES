.. highlight:: perl


##############################
Demeter::UI::Metis::PluckPoint
##############################

****
NAME
****


Demeter::UI::Metis::PluckPoint - Widget for defining a spot for removal from an image


*******
VERSION
*******


See Xray::BLA


********
SYNOPSIS
********


This module provides a dialog for defining a spot in an image to be
removed during the bad/weak step in a recipe.  This dialog prompts an
energy, an x/y position, and a radius, whihc are returned as a
white-space separate string.


.. code-block:: perl

     my $pp = Demeter::UI::Metis::PluckPoint->new($self, $self->{energy}->GetStringSelection, $x, $y);
     if ($pp->ShowModal == wxID_CANCEL) {
       $app->{main}->status("Making spot canceled.");
       return;
     };
     my $line = join("  ",  $pp->{e}->GetValue, $pp->{x}->GetValue, $pp->{y}->GetValue, $pp->{r}->GetValue);


The energy part of this string can refer to a single energy or an
energy range using this syntax:


\ ``energy``\ 
 
 This refers to the elastic image a specific energy.  For example:
 
 
 .. code-block:: perl
 
     11191
 
 


\ ``emin-emax``\ 
 
 This refers to a range of elastic energies, inclusive.  For example:
 
 
 .. code-block:: perl
 
     11194-11196
 
 
 It is important that there be no white space around the dash.
 


\ ``emin+``\ 
 
 This refers to a range of elastic energies beginning at the specified
 value and going to the end of the data set.  For example:
 
 
 .. code-block:: perl
 
      11198+
 
 
 It is important that there be no white space around the plus sign..
 



********************
BUGS AND LIMITATIONS
********************


Please report problems to the Ifeffit Mailing List
(`http://cars9.uchicago.edu/mailman/listinfo/ifeffit/ <http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>`_)

Patches are welcome.


******
AUTHOR
******


Bruce Ravel (bravel AT bnl DOT gov)

`http://github.com/bruceravel/BLA-XANES <http://github.com/bruceravel/BLA-XANES>`_


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2006-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See `perlgpl <http://perldoc.perl.org/perlgpl.html>`_.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

