package Demeter::UI::Metis::Cursor;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);
use Time::HiRes qw(usleep);

use Wx qw( :everything );
use Wx::DND;
use base qw( Exporter );
our @EXPORT = qw(cursor);

use PDL::Graphics::Gnuplot qw(gplot image gpwin);

sub cursor {
  my ($app) = @_;
  my ($x, $y) = (-100000, -100000);

  my $return = Xray::BLA::Return->new();
  my $busy = Wx::BusyCursor->new();
  $app->{main}->status("Double click on a point to pluck its value (there WILL be a short pause after clicking) ...", "wait");
  ($x,$y,$char,$modstring) = $app->{base}->pdlplot->read_mouse('');
  $x = int($x);
  $y = int($y);
  $app->{main}->status(' ');
  undef $busy;
  return($x, $y);
};


1;

=head1 NAME

Demeter::UI::Metis::Cursor - interact with a plotting cursor

=head1 VERSION

See Xray::BLA

=head1 SYNOPSIS

This module provides a way of interacting with the plot cursor in Metis

=head1 METHODS

=over 4

=item C<cursor>

This is exported.  Calling is starts a busy cursor and waits (possibly
forever) for the user to click on a point in the plot window.  It
returns the X and Y coordinate of the point clicked upon.

  my ($x, $y) = $app->cursor;

where C<$app> is a reference to the top level Metis application.

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
