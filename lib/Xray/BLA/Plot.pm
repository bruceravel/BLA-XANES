package Xray::BLA::Plot;

=for Copyright
 .
 Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf.
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
use PDL::Graphics::Gnuplot qw(gplot image gpwin);
use File::Basename;
use List::Util qw(min);
use List::MoreUtils qw(all none any);
use Math::Random;
use Scalar::Util qw(looks_like_number);

has 'cbmax'   => (is => 'rw', isa => 'Int', default => 20,
		  documentation => "Forced upper bound to the color range of the surface plot.");
has 'color'   => (is => 'rw', isa => 'Str', default => 'grey',
		  documentation => 'Color scheme for the palette used in mask surface plots.');
has 'palette' => (is => 'rw', isa => 'Str', ## greys
		  default => "defined ( 0 '#252525', 1 '#525252', 2 '#737373', 3 '#969696', 4 '#BDBDBD', 5 '#D9D9D9', 6 '#F0F0F0', 7 '#FFFFFF' )",
		  documentation => 'The Gnuplot definition of the image plot palette.');
has 'pdlplot' => (is => 'rw', isa => 'Any', default => sub{ gpwin() } );

use Graphics::Gnuplot::Palettes qw(palette palette_names);
has 'splot_palette_name' => (is => 'rw', isa => 'Str', default => 'Parula', #trigger => &set_splot_palette,
			     documentation => 'The name of the surface plot palette.');
has 'splot_palette' => (is => 'rw', isa => 'Str',
			default => sub{palette("Parula")},
			documentation => 'The Gnuplot definition of the surface plot palette.');



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

sub initialize_plot {
  my ($self) = @_;
  $self->pdlplot->output($self->terminal, size=>[675,408,'px']);
  $self->pdlplot->{wait} = Demeter->co->default('metis', 'gnuplot_wait');
  return $self;
};

sub set_palette {
  my ($self, $color) = @_;
  if ($color =~ m{surprise}i) {
    my $i = int(random_uniform(1,0,6));
    $color = (keys %color_choices)[$i];
  };
  if (exists($color_choices{$color})) {
    $self->palette($color_choices{$color});
  };
  return $self;
};

#my %palette_choices = (
#		       parula => $parula, moreland => $moreland, kindlemann => $kindlemann,
#		       jet    => $jet,    pm3d     => $pm3d,     blackbody  => $blackbody,
#		       lineargray => $lineargray
#		      );
sub set_splot_palette {
  my ($self, $pal) = @_;
  $pal ||= $self->splot_palette_name;
  $pal = "Parula" if (none {$_ eq $pal} palette_names);
  $self->splot_palette_name($pal);
  my $posneg = "positive ";
  $posneg = "negative " if ($pal =~ m{Sequential});
  $self->splot_palette($posneg.palette($pal));
  return $self;
};

sub plot_mask {
  my ($self, $type) = @_;
  $type ||= 'single';
  my $title;
  if ($type eq 'aggregate') {
    $title = $self->stub . ' aggregate';
  } else {
    $title = basename($self->elastic_file);
  };
  $title = $self->escape_us($title);
  $self->pdlplot->output($self->terminal, size=>[675,408,'px']);
  #my $point = $self->Read($self->elastic_file);

  $self->pdlplot->image({cbrange=>[0,$self->cbmax], palette=>$self->palette, title=>$title,
			 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts', ymin=>194, ymax=>0, size=>'ratio 0.4'},
			$self->elastic_image);	#                                                ^^ because imagej^^
};			 	                #                                                ^^  is psychotic ^^

sub plot_shield {
  my ($self) = @_;
  return if $self->shield_image->isnull;
  return if $self->shield_image->getndims == 1;
  my $title = "shield for ".basename($self->elastic_file);
  $title = $self->escape_us($title);
  $self->pdlplot->output($self->terminal, size=>[675,408,'px']);
  $self->pdlplot->image({cbrange=>[0,$self->cbmax], palette=>$self->palette, title=>$title,
			 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts', ymin=>194, ymax=>0, size=>'ratio 0.4'},
			$self->shield_image);
};


sub plot_plane {
  my ($self, $holol) = @_;

  my @x = ();
  my @y = ();
  my @z = ();
  my $scale = ($self->div10) ? 10 : 1;
  foreach my $incident (sort {$a <=> $b} keys %$holol) {
    $self->get_incident($incident);
    my $inc = $self->incident;
    push @x, $inc;
    my (@thisy, @thisz);
    foreach my $line (@{$holol->{$incident}}) {
      $self->get_incident($line->[0]);
      my $exc = $self->incident;
      ##                  incident energy  emission en.     energy loss              intensity
      #push @xy, [ $inc/$scale, ($inc-$exc)/$scale, $line->[1] ];
      push @thisy, ($inc-$exc)/$scale;
      push @thisz, $line->[1];
    };
    push @y, \@thisy;
    push @z, \@thisz;
  };

  my $px = PDL::Core::pdl(\@x);
  my $py = PDL::Core::pdl(\@y)->inplace->transpose;
  my $pz = PDL::Core::pdl(\@z)->inplace->transpose;

  # print $px->shape, $/;
  # print $py->shape, $/;
  # print $pz->shape, $/;

  my $xmin = 10 * int($x[0]/10 + 0.5);
  my $xmax = 10 * int($x[-1]/10 + 0.5);
  my $title = "RXES plane for ".$self->stub;
  $title = $self->escape_us($title);
  $self->pdlplot->output($self->terminal, size=>[500,520,'px']);
  $self->pdlplot->image({pm3d=>'map', view=>[0,0,1,1], size=>'0.8, 1', # origin=>'0.02,-0.2',
			 palette=>$self->splot_palette, title=>$title,
			 colorbox=>['user', 'vertical', size=>"0.025,0.7"], #, origin=>"0.03,0.15"],
			 xlabel=>'incident (eV)', ylabel=>'energy loss (eV)', cblabel=>'emission intensity',
			 ymin=>-5, ymax=>40, xtics=>"$xmin,10,$xmax",
			},
			$px, $py, $pz);
};


sub plot_energy_point {
  my ($self, $file, $title) = @_;
  my $point;
  if (ref($file) =~ m{PDL}) {
    $point = $file;
  } elsif (-e $file) {
    $title ||= basename($file);
    $point = $self->Read($file);
  } else {
    print "What are we doing here?\n";
    return;
  };
  $title = $self->escape_us($title);
  my $cbm = min($point->max, 100);
  #my $cbm = $self->bad_pixel_value/$self->imagescale;
  $self->pdlplot->output($self->terminal, size=>[675,408,'px']);
  $self->pdlplot->image({cbrange=>[0, $cbm], palette=>$self->palette, title=>$title, # cbrange=>[0,$cbm],
			 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts', ymin=>194, ymax=>0, size=>'ratio 0.4'},
			$point);
  undef $point;
};

sub plot_xanes {
  my ($self, @args) = @_;
  my %args = @args;
  $args{title} ||= q{};
  $args{mue}   ||= 0;
  $args{pause} = q{-1} if not defined $args{pause};

  my $legend = $self->escape_us($args{title});
  my $mu = ($self->is_windows) ? 'mu' : '{/Symbol m}';
  $self->pdlplot->output($self->terminal, size=>[640,480,'px']);
  if ($args{mue}) {
    $self->pdlplot->gplot({xlabel=>'Energy (eV)', ylabel=>'HERFD', key=>'on inside right bottom box',},

			  with=>'lines', lc=>'rgb blue', lt=>1, lw=>1, legend=>$legend,
			  PDL->new($self->herfd_demeter->ref_array('energy')),
			  PDL->new($self->herfd_demeter->ref_array('flat')),

			  with=>'lines', lc=>'rgb red', lt=>1, lw=>1, legend=>"conventional mu(E)",
			  PDL->new($self->mue_demeter->ref_array('energy')),
			  PDL->new($self->mue_demeter->ref_array('flat'))
	 );
  } else {
    $self->pdlplot->gplot({xlabel=>'Energy (eV)', ylabel=>'HERFD',},
			  with=>'lines', lc=>'rgb blue', lt=>1, lw=>1, legend=>$legend,
			  PDL->new($self->xdata),
			  PDL->new($self->ydata));
  };
  $self->pause($args{pause}) if $args{pause};
}

sub plot_rixs {
  my ($self, @spectra) = @_;
  my ($emin, $emax) = ($spectra[0]->xdata->[0], $spectra[0]->xdata->[-1]);
  my @args;
  if ($#spectra > 40) {
    @args = ({xrange=>[$emin, $emax], xlabel=>'Energy (eV)', ylabel=>'HERFD', key=>'off'});
  } else {
    @args = ({xrange=>[$emin, $emax], xlabel=>'Energy (eV)', ylabel=>'HERFD', key=>'on outside right top box'});
  };
  ## see lib/Demeter/configuration/gnuplot.demeter_conf from Demeter for color list
  my @thiscolor = qw(blue red dark-green dark-violet yellow4 brown dark-pink gold dark-cyan spring-green);
  my $count = 0;
  foreach my $s (@spectra) {
    my $en = ($self->div10) ? $s->energy/10 : $s->energy;
    my $legend = sprintf("%s", $en);
    push @args, with=>'lines', lc=>"rgb ".$thiscolor[$count%10], lt=>1, lw=>1, legend=>[$legend],
      PDL->new($s->xdata), PDL->new($s->ydata)/$s->normpixels;
    ++$count;
    last if (($self->is_windows) and ($count > 25));
  };
  $self->pdlplot->output($self->terminal, size=>[640,480,'px']);
  $self->pdlplot->gplot(@args);
}
sub plot_map {
  my ($self) = @_;
  warn "no map plot yet\n";
}
sub plot_xes {
  my ($self, @args) = @_;
  my %args = @args;
  $args{incident} ||= 0;
  $args{pause}      = q{-1} if not defined $args{pause};
  $args{replot}   ||= 0;
  my (@e, @xes, @n);
  my $denom = ($self->div10) ? 10 : 1;
  foreach my $p (@{$args{xes}}) {
    push @e, $p->[0]/$denom;
    push @xes, $p->[1];
    push @n, $p->[2];
  };
  my $legend = $args{incident};
  if (looks_like_number($legend)) {
    $legend = "incident energy = ".$legend;
  } else {
    $legend =~ s{_}{\\\\_}g;
  };
  my $color = Demeter->co->default('gnuplot', 'col'.$args{replot}%10);
  my $energypdl = PDL->new(\@e);
  my $xespdl = PDL->new(\@xes);
  if ($args{replot} == 0) {
    $self->pdlplot->gplot({xlabel=>'Emission energy (eV)', ylabel=>'XES'},
			  with=>'lines', lc=>'rgb '.$color, lt=>1, lw=>1, legend=>$legend,
			  $energypdl, $xespdl);
  } else {
    $self->pdlplot->replot(with=>'lines', lc=>'rgb '.$color, lt=>1, lw=>1, legend=>$legend,
			   $energypdl, $xespdl);
  };
  #my $xesout = $self->xdi_xes($self->xdi_metadata_file, q{}, $args{xes});
  return [$energypdl, $xespdl, PDL->new(\@n)];
};


sub escape_us {
  my ($self, $string) = @_;
  $string ||= q{};
  if ($self->is_windows) {
    $string =~ s{_}{\\_}g;
  } else {
    $string =~ s{_}{\\\\_}g;
  };
  return $string;
};

sub plot_close {
  my ($self) = @_;
  my $w = gpwin();
  $w->close;
};

1;

=head1 NAME

Xray::BLA::Plot - A plotting role for BLA-XANES

=head1 DESCRIPTION

Various plotting tools using the PDL/Gnuplot interface, inplemented as
a Moose role.

=head1 ATTRIBUTES

This role add these attributes to the Xray::BLA object.

=over 4

=item C<cbmax>

Forced upper bound to the color range of the surface plot.

=item C<color>

Color scheme for the palette used in mask surface plots.  The color
schemes are all monochrome, but of different hues.  The possibilities
are C<black>, C<blue>, C<red>, C<orange>, C<green>, and C<purple>.
This can also be set to C<surprise>, which will randomly choose one of
the defined hues when the first plot is made.

=item C<palette>

This contains the Gnuplot palette definition for the choice of
C<color>.  This is the palette used for elastic and measurement
images and is monotone.

=item C<palette>

This contains the Gnuplot palette definition for surface plots such as
the RXES plane.  This multi-tone palette.

=item C<pdlplot>

This is a reference to the PDL object used to make the plots.

=back

=head1 METHODS

=over 4

=item C<plot_mask>

Make a surface plot of the current state of the elastic image.

  $spectrum -> plot_mask;

This is plotted in the same orientation as ImageJ (i.e. (0,0) is in
the I<upper>, left corner.  That's psychotic, but what can you do...?

=item C<plot_energy_point>

Make a surface plot of a raw image.

  $spectrum -> plot_energy_point;

This is plotted in the same orientation as ImageJ (i.e. (0,0) is in
the I<upper>, left corner.

=item C<plot_xanes>

Make a plot of the computed HERFD.

  $spectrum -> plot_xanes(title=>$title, pause=>0, mue=>$self->{mue}->GetValue);

The arguments are the title of the plot, whether to use
Xray::BLA::Pause, and whether to overplot the HERFD with conventional
XANES (if it exists),

=item C<plot_xes>

Make a plot of the computed XES.

  $spectrum -> plot_xes(pause=>0, incident=>$incident, xes=>$self->{xesdata});

The arguments are whether to use Xray::BLA::Pause, aninteger
identifying the incident energy, and a list reference containing the
XES data.

=item C<plot_rixs>

Make a surface plot of the RIXS plane.

=item C<plot_map>

Make a surface plot of the energy map.

=item C<set_palette>

Change the hue of the image plots.  The choices are grey (the
default), blue, green, orange, purple, and red.

  $spectrum -> set_palette($color);

An unknown color is ignored.  If you do

  $spectrum -> set_palette("surprise");

then one of the hues will be chosen at random.  Ooooh!  Fun!

=back

=head1 DEPENDENCIES

L<PDL::Graphics::Simple> and L<PDL::Graphics::Gnuplot>

=head1 BUGS AND LIMITATIONS

Please report problems as issues at the github site
L<https://github.com/bruceravel/BLA-XANES>

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

The palettes were taken from gnuplot-colorbrewer at
L<https://github.com/Gnuplotting/gnuplot-palettes>, which is written
and maintained by Anna Schneider and released under the Apache License
2.0.  ColorBrewer is a project of Cynthia Brewer, Mark Harrower, and
The Pennsylvania State University.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014,2016 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
