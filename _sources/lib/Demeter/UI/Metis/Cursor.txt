.. highlight:: perl


##########################
Demeter::UI::Metis::Cursor
##########################

****
NAME
****


Demeter::UI::Metis::Cursor - interact with a plotting cursor


*******
VERSION
*******


See Xray::BLA


********
SYNOPSIS
********


This module provides a way of interacting with the plot cursor in Metis


*******
METHODS
*******



\ ``cursor``\ 
 
 This is exported.  Calling is starts a busy cursor and waits (possibly
 forever) for the user to click on a point in the plot window.  It
 returns the X and Y coordinate of the point clicked upon.
 
 
 .. code-block:: perl
 
    my ($x, $y) = $app->cursor;
 
 
 where \ ``$app``\  is a reference to the top level Metis application.
 



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

