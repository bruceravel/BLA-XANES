package Xray::BLA::Tools;

use Moose::Role;

use DateTime;
use Math::Random;

sub file_template {
  my ($self, $tem, $args) = @_;
  my $integer = $args->{counter} || 0;
  my $return_re = $args->{re} || 0;

  my $pattern = '%' . $self->energycounterwidth . '.' . $self->energycounterwidth . 'd';
  my $counter = sprintf($pattern, $integer);

  my %table = (s   => $self->stub,
	       e   => $self->energy,
	       i   => $self->incident,
	       t   => $self->tiffcounter,
	       T   => sprintf("%3.3d", $self->energy),
	       c   => $counter,
	       '%' => '%'
	      );
  if ($return_re) {		# use named captures groups, see
    $table{e} = q{(?<e>\d+)};   # http://perldoc.perl.org/perlre.html#Capture-groups
    $table{c} = q{(?<c>\d+)};
    $table{T} = q{(?<T>\d+)};
  };

  my $regex = '[' . join('', keys(%table)) . ']';
  $tem =~ s{\%($regex)}{$table{$1}}g;

  if ($return_re) {
    $tem =~ s{\.}{\\.}g;
  }

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
    } elsif ($dur->seconds == 0) {
      $text = sprintf "%s took less than 1 second.", $id;
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

Xray::BLA::Tools - A role with tools and conveniences for BLA

=head1 VERSION

See Xray::BLA

=head1 METHODS

=over 4

=item C<file_template>

Construct a file name from BLA object attributes using a simple
%-sign substitution scheme:

   %s : stub
   %e : emission energy
   %i : incident energy
   %t : tiffcounter
   %T : padded, 3-digit energy index
   %c : energy index counter
   %% : literal %

As an example:

   $bla->file_template('%s_elastic_%e_%t.tif')

might evaluate to F<Aufoil1_elastic_9711_00001.tif>.

Optional arguments:

   $bla->file_template('%s_elastic_%e_%t.tif', {counter=>$n, re=>1})

C<counter> is used to increment a file name counter.  C<re> indicates
that the template should return a suitable regular expression for
C<%e> and C<%c>.


=item C<howlong>

Report on a time span in human readable terms.

    my $start = DateTime->now( time_zone => 'floating' );
    ##
    ## do stuff...
    ##
    print $spectrum->howlong($start, $text);

The first argument is a DateTime object created at the beginning of a
lengthy chore.  The second argument is text that will be reported in
the return string, as in "$text took NN seconds".

=item C<randomstring

Return a random string of a specified length, used to make temporary
files and folders.

   my $string = $spectrum->randomstring(6);

The default is a 6-character string.

=item C<is_windows>, C<is_osx>

Return true is the operating system is Windows or OSX.  This is a
simple heuristic based on C<$^O> (see http://perldoc.perl.org/perlvar.html);

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
