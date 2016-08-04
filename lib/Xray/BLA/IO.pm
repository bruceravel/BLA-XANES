package Xray::BLA::IO;


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

use Config::IniFiles;
use Moose::Role;
use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);
use PDL::IO::Dumper;
use List::MoreUtils qw(onlyidx);
use List::Util qw(sum max);
use Math::Round qw(round);

sub mask_file {
  my ($self, $which, $type) = @_;
  $type ||= 'gif';
  $type = 'tif' if ($^O =~ /MSWin32/);
  my $fname;
  if ($which eq 'map') {
    my $range = join("-", $self->elastic_energies->[0], $self->elastic_energies->[-1]);
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $range, "map", "anim").'.');
  } elsif ($which eq 'anim') {
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, "mask", "anim").'.');
  } elsif ($which eq 'maskmap') {
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, "mapmask").'.');
    $type = 'dump';
  } elsif ($which eq 'rixsplane') {
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, "rixsplane").'.');
    $type = 'dat';
  } elsif ($which eq 'shield') {
    my $energy = $self->energy;
    $energy = sprintf("%3.3d", $self->energy) if $energy < 1000;
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $energy, "shield").'.');
  } elsif ($which eq 'previousshield') {
    my $i = onlyidx {$_ == $self->energy} @{$self->elastic_energies};
    return q{} if not $i;
    my $prev = $self->elastic_energies->[$i-1];
    $prev = sprintf("%3.3d", $prev) if $prev < 1000;
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $prev, "shield").'.');
  } else {
    my $id = ($which eq 'mask') ? q{} :"_$which";
    my $energy = $self->energy;
    $energy = sprintf("%3.3d", $self->energy) if $energy < 1000;
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $energy, "mask$id").'.');
  };
  $fname .= $type;
  return $fname;
};


##################################################################################
## output: column data files
##################################################################################

sub xdi_out {
  my ($self, $xdiini, $rdata) = @_;
  my $fname = join("_", $self->stub, $self->energy) . '.xdi';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);
  open(my $O, '>', $outfile);
  my $pilatus = $self->fetch_metadata($self->elastic_image);
  print $O "# XDI/1.0 PILATUS/100K BLA/" . $Xray::BLA::VERSION, $/;

  my @labels = ();
  my @units  = ();
  my %beamline;
  if (ref($xdiini) eq q{HASH}) {
    %beamline = %$xdiini;
  } elsif ($xdiini and -e $xdiini) {
    tie %beamline, 'Config::IniFiles', ( -file => $xdiini );
  } elsif (-e $self->xdi_metadata_file) {
    tie %beamline, 'Config::IniFiles', ( -file => $self->xdi_metadata_file );
  };

  foreach my $fam (sort keys %beamline) {
    next if $fam eq 'xescolumn';
    foreach my $item (sort keys %{$beamline{$fam}}) {
      printf $O "# %s.%s: %s\n", ucfirst($fam), $item, $beamline{$fam}->{$item};
    };
  };
  foreach my $lab (sort keys %{$beamline{column}}) {
    my @this = split(" ", $beamline{column}->{$lab});
    push @labels, $this[0];
    push @units,  $this[1] || q{};
  };

  printf $O "# %s.%s: %s\n", "PILATUS", "model", $pilatus->{Model}                       if $pilatus->{Model};
  printf $O "# %s.%s: %s\n", "PILATUS", "threshold_energy", $pilatus->{Threshold_energy} if $pilatus->{Threshold_energy};
  printf $O "# %s.%s: %s\n", "PILATUS", "height", $pilatus->{height}                     if $pilatus->{height};
  printf $O "# %s.%s: %s\n", "PILATUS", "width", $pilatus->{width}                       if $pilatus->{width};
  printf $O "# %s.%s: %s\n", "BLA", "illuminated_pixels", $self->npixels;
  printf $O "# %s.%s: %s\n", "BLA", "total_pixels", $self->columns*$self->rows;
  if ($self->task eq 'rixs') {
    printf $O "# %s.%s: %s\n", "BLA", "pixel_ratio", "\%pixel_ratio\%";
  };
  print $O "# /////////////////////////\n";
  print $O "# HERFD scan on " . $self->stub . $/;
  print $O "# Mask building steps:\n";
  foreach my $st (@{$self->steps}) {
    print $O "#   $st\n";
  };
  print $O "# -------------------------\n";
  print $O "#  ", join("       ", @labels), $/;
  foreach my $p (@$rdata) {
    foreach my $datum (@$p) {
      printf $O "  %.7f", $datum;
    };
    print $O $/;
  };
  close $O;
  return $outfile;
};

sub dat_out {
  my ($self, $rdata) = @_;
  my $fname = join("_", $self->stub, $self->energy) . '.dat';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  open(my $O, '>', $outfile);
  print   $O "# HERFD scan on " . $self->stub . $/;
  printf  $O "# %d illuminated pixels (of %d) in the mask\n", $self->npixels, $self->columns*$self->rows;
  printf  $O "# Mask building steps:\n";
  foreach my $st (@{$self->steps}) {
    printf  $O "#    $st\n";
  };
  print   $O "# -------------------------\n";
  print   $O "#   energy      mu           i0           it          ifl         ir          herfd   time    ring_current\n";
  foreach my $p (@$rdata) {
    printf $O "  %.3f  %.7f  %10d  %10d  %10d  %10d  %10d  %4d  %8.3f\n", @$p;
  };
  close   $O;
  return $outfile;
};


sub xdi_xes_head {
  my ($self, $xdiini, $xesimage) = @_;
  my $text = "# XDI/1.0 PILATUS/100K BLA/" . $Xray::BLA::VERSION . $/;
  my %beamline;
  if (ref($xdiini) eq q{HASH}) {
    %beamline = %$xdiini;
  } elsif ($xdiini and -e $xdiini) {
    tie %beamline, 'Config::IniFiles', ( -file => $xdiini );
  } elsif (-e $self->xdi_metadata_file) {
    tie %beamline, 'Config::IniFiles', ( -file => $self->xdi_metadata_file );
  };
  foreach my $fam (sort keys %beamline) {
    next if $fam eq 'column';
    my $this = ($fam eq 'xescolumn') ? 'column' : $fam;
    foreach my $item (sort keys %{$beamline{$fam}}) {
      $text .= sprintf "# %s.%s: %s\n", ucfirst($this), $item, $beamline{$fam}->{$item};
    };
  };
  $text .= sprintf "# %s.%s: %s\n", "Element", "element", $self->element;
  $text .= sprintf "# %s.%s: %s\n", "Element", "line", $self->line;
  if ($xesimage) {
    my $pilatus = $self->fetch_metadata($xesimage);
    if (%$pilatus) {
      $text .= sprintf "# %s.%s: %s\n", "PILATUS", "model", $pilatus->{Model};
      $text .= sprintf "# %s.%s: %s\n", "PILATUS", "threshold_energy", $pilatus->{Threshold_setting};
      $text .= sprintf "# %s.%s: %s\n", "PILATUS", "height", $pilatus->{height};
      $text .= sprintf "# %s.%s: %s\n", "PILATUS", "width", $pilatus->{width};
      $text .= sprintf "# %s.%s: %s\n", "BLA", "xesimage", $xesimage if $xesimage;
    };
  };
  $text .= "# /////////////////////////\n";
  return $text;
};

sub xdi_xes {
  my ($self, $xdiini, $xesimage, $rdata) = @_;
  my $fname;
  if ($self->incident < 1000) {
    $fname = join("_", $self->stub, 'xes', sprintf('%2.2d', $self->incident)) . '.xdi';
  } else {
    $fname = join("_", $self->stub, 'xes', $self->incident) . '.xdi';
  };
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);
  open(my $O, '>', $outfile);

  print $O $self->xdi_xes_head($xdiini, $xesimage);
  print $O "# Mask building steps:\n";
  foreach my $st (@{$self->steps}) {
    print $O "#   $st\n";
  };
  printf $O "# Excluded region: xrange = %d %d\n", $self->width_min, $self->width_max;
  if (@{$self->spots}) {
    print $O "# Spots:\n";
    foreach my $sp (@{$self->spots}) {
      print $O "#   " . join(" ", @$sp) . "\n";
    };
  };
  print $O "# -------------------------\n";
  print $O '#  ' . join("      ", qw(energy xes npixels raw)), $/;
  foreach my $p (@$rdata) {
    $p->[0] /= 10 if $self->div10;
    printf $O "  %.3f  %.7f  %6d  %.7f\n", @$p;
  };
  close $O;
  return $outfile;
};

## $rdata is an arrayref of PDLS: [E, merged, N, x1, x2, .. xn]
## so the derefencing is confusing
##   $rdata->[0] is the energy PDL, $rdata->[1] is the merge PDL, etc
##   $rdata->[0]->dim(0) is the length of each PDL, i.e. the number of elastic energy points
##   $rdata->[0]->($i)->sclr is the energy at point $i, expressed as a scalar
##   $rdata->[1]->($i)->sclr is the merge at point $i, expressed as a scalar, and so on
sub xdi_xes_merged {
  my ($self, $xdiini, $rdata) = @_;
  my $fname;
  if ($self->incident < 1000) {
    $fname = join("_", $self->stub, 'xes', sprintf('%2.2d', $self->incident)) . '.xdi';
  } else {
    $fname = join("_", $self->stub, 'xes', $self->incident) . '.xdi';
  };
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);
  open(my $O, '>', $outfile);

  print $O $self->xdi_xes_head($xdiini, q{});
  print $O "# Mask building steps:\n";
  foreach my $st (@{$self->steps}) {
    print $O "#   $st\n";
  };
  printf $O "# Excluded region: xrange = %d %d\n", $self->width_min, $self->width_max;
  if (@{$self->spots}) {
    print $O "# Spots:\n";
    foreach my $sp (@{$self->spots}) {
      print $O "#   " . join(" ", @$sp) . "\n";
    };
  };
  print $O "# -------------------------\n";
  print $O '#  ' . join("      ", qw(energy xes npixels)) . join("      ", (1 .. $#{$rdata}-2)), $/;
  foreach my $i (0 .. $rdata->[0]->dim(0) - 1) {
    #my $e = $rdata->[0]->($i)->sclr;
    #$e /= 10 if $self->div10;
    printf $O "  %.3f  %.7f  %6d", $rdata->[0]->($i)->sclr, $rdata->[1]->($i)->sclr, $rdata->[2]->($i)->sclr;
    foreach my $j (3 .. $#{$rdata}) {
      printf $O "  %.7f", $rdata->[$j]->($i)->sclr;
    };
    printf $O "\n";
  };

  close $O;
  return $outfile;
};

sub dat_xes {
  my ($self, $rdata) = @_;
  my $fname = join("_", $self->stub, 'xes', $self->incident) . '.dat';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  open(my $O, '>', $outfile);
  print   $O "# XES from " . $self->stub . " at " . $self->incident . ' eV' . $/;
  print   $O "# -------------------------\n";
  print   $O "#   energy      xes    npixels    raw\n";
  foreach my $p (@$rdata) {
    $p->[0] /= 10 if $self->div10;
    printf $O "  %.3f  %.7f  %6d  %.7f\n", @$p;
  };
  close   $O;
  return $outfile;
};



##################################################################################
## output: ascii map files
##################################################################################

sub energy_map {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{animate} ||= 0;
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  ## determine the average step between elastic measurements
  my @energies = sort {$a <=> $b} @{$self->elastic_energies};
  my $step = round( sum(map {$energies[$_+1] - $energies[$_]} (0 .. $#energies-1)) / $#energies );

  ## import the gifs of each elastic map
  my @images = map {rim($_)} @{$self->elastic_file_list};
  $self -> elastic_image_list(\@images);

  my $mapmask = PDL::Core::zeros($self->columns, $self->rows);

  my $counter;
  $counter = Term::Sk->new('Making map, time elapsed: %8t %15b (row %c of %m)',
			   {freq => 's', base => 0, target=>$self->rows}) if ($self->ui eq 'cli');
  my $outfile = File::Spec->catfile($self->outfolder, $self->stub.'.map');
  my $maskfile = $self->mask_file("maskmap", $self->outimage);

  open(my $M, '>', $outfile);
  printf $M "# Energy calibration map for %s\n", $self->stub;
  printf $M "# Elastic energy range [%s : %s]\n", $energies[0], $energies[-1];
  print  $M "# ----------------------------------\n";
  print  $M "# row  column  interpolated_energy\n\n";
  my $ncols = $self->columns - 1;

  foreach my $r (0 .. $self->rows-1) {
    $counter->up if ($self->screen and ($self->ui eq 'cli'));

    my @represented = map {[0]} (0 .. $self->columns-1);
    my @linemap = map {0} (0 .. $self->columns-1);
    my (@x, @y);
    my @all = ();

    ## gather current row from each mask
    foreach my $ie (0 .. $#{$self->elastic_energies}) {
      ## extract the $r-th row from each image and fl;atten it to a 1D PDL
      my $y = $self->elastic_image_list->[$ie] -> (0:$ncols,$r) -> flat;
      push @all, $y;
    };


    ## accumulate energies at which each pixel is illuminated
    my $stripe = 0;
    foreach my $list (@all) {
      foreach my $p (0 .. $ncols) {
	if ($list->at($p) > 0) {
	  push @{$represented[$p]}, $self->elastic_energies->[$stripe];
	};
      };
      ++$stripe;
    };

    ## make each pixel the average of energies at which the pixel is illuminated
    foreach my $i (0 .. $#represented) {
      my $n = sprintf("%.1f", $#{$represented[$i]});
      my $val = '(' . join('+', @{$represented[$i]}) . ')/' . $n;
      $linemap[$i] = eval "$val" || 0;
    };

    ## linearly interpolate from the left to fill in any gaps from the measured masks
    $linemap[0] ||= $self->elastic_energies->[0]-$step;
    my $flag = 0;
    my $first = 0;
    foreach my $k (1 .. $#linemap) {
      $flag = 1 if ($linemap[$k] == 0);
      $first = $k if not $flag;
      if ($flag and ($linemap[$k] > 0)) {
	my $emin = $linemap[$first];
	my $ediff = $linemap[$k] - $emin;
	foreach my $j ($first .. $k-1) {
	  $linemap[$j] = $emin + (($j-$first)/($k-$first)) * $ediff;
	};
	$flag = 0;
      };
    };
    if ($flag) {
      my $emin = $linemap[$first-1];
      my $ediff = $step; # FIXME: this should be the actual step between adjacent elastic measurements
      foreach my $j ($first .. $#linemap) {
	$linemap[$j] = $emin + (($j-$first)/($#linemap-$first)) * $ediff;
      };
    };

    ## do three-point smoothing to smooth over abrupt steps in energy
    my @zz = $self->_smooth($self->nsmooth, \@linemap);

    ## write this row
    foreach my $i (0..$#zz) {
      print $M "  $r  $i  $zz[$i]\n";
      $mapmask->($i, $r) .= $zz[$i];
    };
    print $M $/;
  };
  $counter->close if ($self->screen and ($self->ui eq 'cli'));
  close $M;
  fdump($mapmask, $maskfile);
  print $self->report("Wrote calibration map to $outfile", 'bold green') if $args{verbose};
  print $self->report("Wrote calibration image to $maskfile", 'bold green') if $args{verbose};


  ## write a usable gnuplot script for plotting the data
  my $gpfile = File::Spec->catfile($self->outfolder, $self->stub.'.map.gp');
  my $gp = $self->gnuplot_map;
  my $tmpl = Text::Template->new(TYPE=>'string', SOURCE=>$gp)
    or die "Couldn't construct template: $Text::Template::ERROR";
  open(my $G, '>', $gpfile);
  (my $stub = $self->stub) =~ s{_}{\\\\_}g;
  my $peak = Xray::Absorption->get_energy($self->element, $self->line)
    || ( ($self->elastic_energies->[$#{$self->elastic_energies}]+$self->elastic_energies->[0]) /2 );
  print $G my $string = $tmpl->fill_in(HASH => {emin  => $self->elastic_energies->[0],
						emax  => $self->elastic_energies->[$#{$self->elastic_energies}],
						file  => $outfile,
						stub  => $stub,
						nrows => $self->rows,
						ncols => $self->columns,
						step  => $step,
						peak  => $peak,
					       });
  close $G;
  print $self->report("Wrote gnuplot script to $gpfile", 'bold green') if $args{verbose};
  $ret->message($gpfile);

  if ($args{animate}) {
    my $animfile = $self->animate('map', @{$self->elastic_file_list});
    print $self->report("Wrote gif animation of energy map to $animfile", 'bold green') if $args{verbose};
  };

  return $ret;
};


## swiped from ifeffit-1.2.11d/src/lib/decod.f, lines 453-461
sub _smooth {
  my ($self, $repeats, $rarr) = @_;
  my @array = @$rarr;
  return @array if ($repeats == 0);
  my @smoothed = ();
  foreach my $x (1 .. $repeats) {
    $smoothed[0] = 3*$array[0]/4.0 + $array[1]/4.0;
    foreach my $i (1 .. $#array-1) {
      $smoothed[$i] = ($array[$i] + ($array[$i+1] + $array[$i-1])/2.0)/2.0;
    };
    $smoothed[$#array] = 3*$array[$#array]/4.0 + $array[$#array-1]/4.0;
    @array = @smoothed;
  };
  return @smoothed;
};



##################################################################################
## output: gnuplot scripts
##################################################################################

sub gnuplot_map {
  my ($self) = @_;
  my $text = q<set term wxt font ",9"  enhanced

set auto
set key default
set pm3d map

set title "\{/=14 {$stub} energy map\}" offset 0,-5
set ylabel "\{/=11 columns\}" offset 0,2.5

set view 0,90,1,1
set origin -0.17,-0.2
set size 1.4,1.4
unset grid

unset ztics
unset zlabel
set xrange [{$nrows}:0]
set yrange [0:{$ncols}]
set cbtics {$emin-$step}, {2*$step}, {$emax+$step}
set cbrange [{$emin-$step}:{$emax+$step}]

set colorbox vertical size 0.025,0.65 user origin 0.03,0.15

set palette model RGB defined ( {$emin-$step-$peak} 'red', 0 'white', {$emax+$step-$peak} 'blue' )

splot '{$file}' title ''
>;
  return $text;
};

## heat scale
#set palette model RGB defined ( -1 'black', 0 'red', 1 'yellow', 2 'white' )

## undersaturated rainbow
#set palette model RGB defined (0 '#990000', 1 'red', 2 'orange', 3 'yellow', 4 'green', 5 '#009900', 6 '#006633', 7 '#0066DD', 8 '#000099')

## gray scale
#set palette model RGB defined ( 0 'black', 1 'white' )


1;


=head1 NAME

Xray::BLA::IO - Role containing input and output operations

=head1 VERSION

See Xray::BLA

=head1 METHODS

=over 4

=item C<mask_file>

Compute the name of an output file from the parameters of the
calculation.

   my $fname = $self->mask_file($type, $imagetype);

C<$type> is one of C<mask>, C<shield>, C<previousshield>,
C<rixsplane>, C<anim>, C<map>, C<maskmap>, or an integer denoting a
file in a sequence.

C<imagetype> is one of "gif", "tif", or "png" and specifies the output
image format.

=item C<xdi_out>

Write HERFD data to an XDI file.  Return the name of the computed
output file.  The arguments are the name of the ini file with XDI
metadata and a reference to the hash containing the calculated HERFD
data.

   $outfile = $self->xdi_out($xdiini, \@data);

C<$xdiini> can be a string with the fully resolved path to an
INI-style file containing the meatdata for the measurement.  It can
also be a hash reference containing the metadata as a hash or hashes
where the outer hash contains the metadata families and the inner
hashes contain the items in each family.  See
L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>.

=item C<xdi_xes>

Write XES data to an XDI file.  Return the name of the computed output
file.  The arguments are the name of the ini file with XDI metadata,
the name of the XES image file, and a reference to the hash containing
the calculated XES data.

   my $outfile = $self->xdi_xes($xdiini, $xesimage, \@xes);

C<$xdiini> can be a string with the fully resolved path to an
INI-style file containing the meatdata for the measurement.  It can
also be a hash reference containing the metadata as a hash or hashes
where the outer hash contains the metadata families and the inner
hashes contain the items in each family.  See
L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>.

=item C<energy_map>

Write the results of the C<map> task to an output data file.  The
arguments control screen output and the creation (not currently
working) of an animation showing how the energy map was made.

   my $spectrum -> energy_map(verbose => 1, animate=>0);

=item C<gnuplot_map>

Write gnuplot commands to use the data written by C<energy_map>.

   open(my $GP, '>', 'splot.gp');
   my $gp = $self->gnuplot_map;
   print $GP $gp;
   close $GP;


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
