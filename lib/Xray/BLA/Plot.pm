package Xray::BLA::Plot;

=for Copyright
 .
 Copyright (c) 2011-2014 Bruce Ravel, Jeremy Kropf.
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

has 'color'   => (is => 'rw', isa => 'Str', default => 'grey');
has 'palette' => (is => 'rw', isa => 'Str',
		  ## greys
		  default => "defined ( 0 '#252525', 1 '#525252', 2 '#737373', 3 '#969696', 4 '#BDBDBD', 5 '#D9D9D9', 6 '#F0F0F0', 7 '#FFFFFF' )",
		  );

## These are the single hue, sequential palettes from Color Brewer
##   http://colorbrewer2.org/
## The gnuplot definitions are from
##   https://github.com/aschn/gnuplot-colorbrewer
## I reversed the order so that white is the top of the color scale in each case
my %color_choices = (
		     grey   => "defined ( 0 '#252525', 1 '#525252', 2 '#737373', 3 '#969696', 4 '#BDBDBD', 5 '#D9D9D9', 6 '#F0F0F0', 7 '#FFFFFF' )",
		     green  => "defined ( 0 '#005A32', 1 '#238B45', 2 '#41AB5D', 3 '#74C476', 4 '#A1D99B', 5 '#C7E9C0', 6 '#E5F5E0', 7 '#F7FCF5' )",
		     blue   => "defined ( 0 '#084594', 1 '#2171B5', 2 '#4292C6', 3 '#6BAED6', 4 '#9ECAE1', 5 '#C6DBEF', 6 '#DEEBF7', 7 '#F7FBFF' )",
		     orange => "defined ( 0 '#8C2D04', 1 '#D94801', 2 '#F16913', 3 '#FD8D3C', 4 '#FDAE6B', 5 '#FDD0A2', 6 '#FEE6CE', 7 '#FFF5EB' )",
		     purple => "defined ( 0 '#4A1486', 1 '#6A51A3', 2 '#807DBA', 3 '#9E9AC8', 4 '#BCBDDC', 5 '#DADAEB', 6 '#EFEDF5', 7 '#FCFBFD' )",
		     red    => "defined ( 0 '#99000D', 1 '#CB181D', 2 '#EF3B2C', 3 '#FB6A4A', 4 '#FC9272', 5 '#FCBBA1', 6 '#FEE0D2', 7 '#FFF5F0' )",
		    );

sub set_palette {
  my ($self, $color) = @_;
  if (exists($color_choices{$color})) {
    $self->palette($color_choices{$color});
  };
  return $self;
};


sub plot_mask {
  my ($self) = @_;
  (my $title = basename($self->elastic_file)) =~ s{_}{\\\\_}g;
  image({cbrange=>[0,$self->cbmax], palette=>$self->palette, title=>$title,
	 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts'},
	$self->elastic_image);
};

sub plot_aggregate {
  my ($self) = @_;
  (my $title = $self->stub) =~ s{_}{\\\\_}g;
  image({cbrange=>[0,$self->cbmax], palette=>$self->palette, title=>$title." aggregate",
	 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts'},
	$self->elastic_image);
};

sub plot_energy_point {
  my ($self, $file) = @_;
  my $point = $self->Read($file);
  my $cbm = $self->bad_pixel_value/$self->imagescale;
  (my $title = basename($file)) =~ s{_}{\\\\_}g;
  image({cbrange=>[0,$cbm], palette=>$self->palette, title=>$title,
	 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts'},
	$point);
  undef $point;
};

sub plot_xanes {
  my ($self, $fname, @args) = @_;
  my %args = @args;
  $args{title} ||= q{};
  $args{mue}   ||= 0;
  $args{pause} = q{-1} if not defined $args{pause};

  (my $legend = $args{title}) =~ s{_}{\\\\_}g;
  if ($args{mue}) {
    gplot({xlabel=>'Energy (eV)', ylabel=>'HERFD'},
	  with=>'lines', legend=>$legend, PDL->new($self->xdata), PDL->new($self->ydata),
	  with=>'lines', legend=>'conventional {/Symbol m}(E)', PDL->new($self->xdata), PDL->new($self->mudata)
	 );
  } else {
    gplot({xlabel=>'Energy (eV)', ylabel=>'HERFD'},
	  with=>'lines', legend=>$legend, PDL->new($self->xdata), PDL->new($self->ydata));
  };
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

=item C<set_palette>

Change the hue of the image plots.  The choices are grey (the
default), blue, green, orange, purple, and red.

  $spectrum -> set_palette($color);

An unkown color is ignored.

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

gnuplot-colorbrewer is written and maintained by Anna Schneider
<annarschneider AT gmail DOT com> and released under the Apache
License 2.0.  ColorBrewer is a project of Cynthia Brewer, Mark
Harrower, and The Pennsylvania State University.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
