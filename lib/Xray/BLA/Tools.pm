package Xray::BLA::Tools;

use Moose::Role;

use DateTime;
use Math::Random;

sub file_template {
  my ($self, $tem, $integer) = @_;
  $integer ||= 0;

  my $pattern = '%' . $self->energycounterwidth . '.' . $self->energycounterwidth . 'd';
  my $counter = sprintf($pattern, $integer);

  my %table = (s   => $self->stub,
	       e   => $self->energy,
	       i   => $self->incident,
	       t   => $self->tiffcounter,
	       c   => $counter,
	       '%' => '%'
	      );

  my $regex = '[' . join('', keys(%table)) . ']';
  $tem =~ s{\%($regex)}{$table{$1}}g;
  return $tem;
};


sub howlong {
  my ($self, $start, $id) = @_;
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->delta_ms($start);
  $id ||= 'That';
  my $text;
  if ($dur->minutes) {
    if ($dur->minutes == 1) {
      $text = sprintf "%s took %d minute and %d seconds.", $id, $dur->minutes, $dur->seconds;
    } else {
      $text = sprintf "%s took %d minutes and %d seconds.", $id, $dur->minutes, $dur->seconds;
    };
  } else {
    if ($dur->seconds == 1) {
      $text = sprintf "%s took %d second.", $id, $dur->seconds;
    } else {
      $text = sprintf "%s took %d seconds.", $id, $dur->seconds;
    };
  };
  return $text;
};

sub randomstring {
  my ($self, $length) = @_;
  $length ||= 6;
  my $rs = q{};
  foreach (1..$length) {
    $rs .= chr(int(26*random_uniform)+97);
  };
  return $rs;
};

sub is_windows {
  my ($class) = @_;
  return (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
};
sub is_osx {
  my ($class) = @_;
  return ($^O eq 'darwin');
};

1;

=head1 NAME

Xray::BLA::Tools - Tools and conveniences for BLA

=head1 VERSION

See L<Xray::BLA>

=head1 METHODS

=over 4

=item C<file_template>

Construct a file name from BLA object attributes using a simple
%-sign substitution scheme:

   %s : stub
   %e : emission energy
   %i : incident energy
   %t : tiffcounter
   %c : energy index counter
   %% : literal %

As an example:

   $bla->file_template('%s_elastic_%e_%t.tif')

might evaluate to F<Aufoil1_elastic_9711_00001.tif>.

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014 Bruce Ravel, Jeremy Kropf. All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
