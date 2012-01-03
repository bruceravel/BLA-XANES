package Xray::BLA::Return;

use Moose;

has 'status'  => (is => 'rw', isa => 'Int',  default => 1);
has 'message' => (is => 'rw', isa => 'Str',  default => q{});

sub is_ok {
  my ($self) = @_;
  return 0 if not $self->status;
  return 1;
};

1;

=head1 NAME

Xray::BLA::Return - A simple return object for use with Xray::BLA

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

