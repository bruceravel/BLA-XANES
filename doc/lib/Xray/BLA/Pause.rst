.. highlight:: perl


################
Xray::BLA::Pause
################

****
NAME
****


Xray::BLA::Pause - A generic pause method for the screen UI


********
SYNOPSIS
********



.. code-block:: perl

    $spectrum->pause(-1);



***********
DESCRIPTION
***********


This role for a Demeter object provides a generic and easy-to-use
pause when using the terminal.  This role is imported when the UI mode
is set to "screen".  See Demeter/PRAGMATA.

Trying to use the \ ``pause``\  method without being in screen mode will do
nothing.  That is because there is a pause method in the base class
that does nothing.  That no-op gets overridden when in screen mode
with this more useful method.  Note, however, that the attributes
documented below do not exist in the base class and will return the
"Can't locate object method" error when you attempt to access them
outside of screen mode.


**********
ATTRIBUTES
**********



\ ``prompt``\ 
 
 The text of the carriage return prompt which is displayed when not
 pausing for specified amount of time.  The default is
 
 
 .. code-block:: perl
 
    Hit return to continue>
 
 
 If ANSI colors are available, the prompt will be displayed in reverse
 colors (usually black on white).  The ANSI colors control sequences
 are part of the default value of this attribute and so can be
 overriden by resetting its value.
 


\ ``highlight``\  [underline]
 
 This sets the form of highlighting of the prompt.  The possible values
 are underline and reverse, which will cause the prompt text to be
 either underlined or reverse video in the sense of \ ``Term::ANSIColor``\ .
 Any other value for this attribute will result in no highlighting of
 the prompt string.
 


\ ``hl``\ 
 
 This contains the ASCII escape sequence associated with \ ``highlight``\ .
 



*******
METHODS
*******



\ ``pause``\ 
 
 This pauses either for the amount of time indicated in seconds or, if
 the argument is zero or negative, until the enter key is pressed.
 
 
 .. code-block:: perl
 
     $object->pause(-1);
 
 
 This method returns whatever string is entered before return is hit.
 So this method could be used, for example, to prompt for the answer
 with a question.
 
 
 .. code-block:: perl
 
     $object->prompt("What is 2+2? ");
     my $answer = $object->pause;
     chomp $answer;
     if (($answer eq '4') or (uc($answer) eq 'IV')) {
        print "You're a math genius!\n";
     } else {
        print "Sigh. I don't know why I even bother....\n";
     };
 
 



************
DEPENDENCIES
************


Demeter's dependencies are in the \ *Bundle/DemeterBundle.pm*\  file.
This module uses `Term::ANSIColor <https://metacpan.org/pod/Term%3a%3aANSIColor>`_ if it is available.


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


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2006-2014,2016 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See `perlgpl <http://perldoc.perl.org/perlgpl.html>`_.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

