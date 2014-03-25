package Xray::BLA::Plot;

=for Copyright
 .
 Copyright (c) 2011-2012 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Moose::Role;
use PDL::Graphics::Simple;
use PDL::Graphics::Gnuplot qw(gplot image);
use File::Basename;

has 'cbmax' => (is => 'rw', isa => 'Int', default => 20);

has 'palette' => (is => 'rw', isa => 'Str',
		  #default=>"negative defined ( 0 '#D53E4F', 1 '#F46D43', 2 '#FDAE61', 3 '#FEE08B', 4 '#E6F598', 5 '#ABDDA4', 6 '#66C2A5', 7 '#3288BD' )",
		  #default => "defined ( 0 '#FFFFFF', 1 '#F0F0F0', 2 '#D9D9D9', 3 '#BDBDBD', 4 '#969696', 5 '#737373', 6 '#525252', 7 '#252525' )",
		  default => "defined ( 0 '#252525', 1 '#525252', 2 '#737373', 3 '#969696', 4 '#BDBDBD', 5 '#D9D9D9', 6 '#F0F0F0', 7 '#FFFFFF' )",
		  );

sub plot_mask {
  my ($self) = @_;
  (my $title = basename($self->elastic_file)) =~ s{_}{\\\\_}g;
  image({cbrange=>[0,$self->cbmax], palette=>$self->palette, title=>$title,
	 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts'},
	$self->elastic_image);
};

sub plot_energy_point {
  my ($self, $file) = @_;
  my $img = Xray::BLA::Image->new(parent=>$self);
  my $point = $img->Read($file);
  my $cbm = $self->bad_pixel_value/$self->imagescale;
  (my $title = basename($file)) =~ s{_}{\\\\_}g;
  image({cbrange=>[0,$cbm], palette=>$self->palette, title=>$title,
	 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts'},
	$point);
  undef $img; undef $point;
};

sub plot_xanes {
  my ($self, $fname, @args) = @_;
  my %args = @args;
  $args{title} ||= q{};
  $args{pause} = q{-1} if not defined $args{pause};

  (my $legend = $args{title}) =~ s{_}{\\\\_}g;
  gplot({xlabel=>'Energy (eV)', ylabel=>'HERFD'},
	with=>'lines', legend=>$legend, PDL->new($self->xdata), PDL->new($self->ydata));
  $self->pause($args{pause}) if $args{pause};
}

sub plot_rixs {
  my ($self) = @_;
  warn "no rixs plot yet\n";
}
sub plot_map {
  my ($self) = @_;
  warn "no map plot yet\n";
}
sub plot_xes {
  my ($self) = @_;
  warn "no xes plot yet\n";
}


1;

=head1 NAME

Xray::BLA::Plot - A plotting method for BLA-XANES

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item C<plot_mask>

=item C<plot_energy_point>

=item C<plot_xanes>

=item C<plot_xes>

=item C<plot_rixs>

=item C<plot_map>

=back

=head1 DEPENDENCIES

L<PDL::Graphics::Gnuplot>

=head1 BUGS AND LIMITATIONS

Please report problems as issues at the github site
L<https://github.com/bruceravel/BLA-XANES>

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
