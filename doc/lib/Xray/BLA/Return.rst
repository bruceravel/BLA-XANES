.. highlight:: perl


#################
Xray::BLA::Return
#################

****
NAME
****


Xray::BLA::Return - A simple return object for use with Xray::BLA


**********
ATTRIBUTES
**********



\ ``status``\ 
 
 A numerical status.  Evaluates to false to indicate a problem.  Also
 used to return a numerical value for a successful return.
 


\ ``message``\ 
 
 A string response.  This eaither returns an exception message or
 textual information about a successful return.
 



*******
METHODS
*******



\ ``is_ok``\ 
 
 Returns true if no problem is reported.
 
 
 .. code-block:: perl
 
     my $ret = $object -> some_method;
     do {something} if $ret->is_ok;
  
     my $ret = $object -> some_method;
     die $ret->message if not $ret->is_ok;
 
 



******
AUTHOR
******


Bruce Ravel (bravel AT bnl DOT gov)

`http://github.com/bruceravel/BLA-XANES <http://github.com/bruceravel/BLA-XANES>`_


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See perlgpl.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

