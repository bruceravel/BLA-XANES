package Xray::BLA::IO;


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
use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);
use PDL::IO::Dumper;

sub import_elastic_image {
  my ($self, @args) = @_;
  my %args = @args;
  #$args{write} ||= 0;
  $args{write} = 0;

  my $ret = Xray::BLA::Return->new;

  my ($c, $r) = $self->elastic_image->dims;
  $self->columns($c);
  $self->rows($r);
  my $str = $self->report("\nProcessing ".$self->elastic_file, 'yellow');
  $str   .= sprintf "\tusing the %s backend\n", $self->backend;
  $str   .= sprintf "\t%d columns, %d rows, %d total pixels\n",
    $self->columns, $self->rows, $self->columns*$self->rows;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

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
  } else {
    my $id = ($which eq 'mask') ? q{} :"_$which";
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->energy, "mask$id").'.');
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

  my $xdi = Xray::XDI->new();
  $xdi   -> ini($xdiini);
  $xdi   -> push_extension(sprintf("BLA.illuminated_pixels: %d", $self->npixels));
  $xdi   -> push_extension(sprintf("BLA.total_pixels: %d", $self->columns*$self->rows));
  $xdi   -> push_extension("BLA.pixel_ratio: \%pixel_ratio\%") if ($self->task eq 'rixs');
  $xdi   -> push_comment("HERFD scan on " . $self->stub);
  $xdi   -> push_comment("Mask building steps:");
  foreach my $st (@{$self->steps}) {
    $xdi -> push_comment("  $st");
  };
  $xdi   -> data($rdata);
  $xdi   -> export($outfile);
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



sub xdi_xes {
  my ($self, $xdiini, $rdata) = @_;
  my $fname = join("_", $self->stub, 'xes', $self->incident) . '.xdi';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  my $xdi = Xray::XDI->new();
  $xdi   -> ini($xdiini);
  $xdi   -> push_comment("XES from " . $self->stub . " at " . $self->incident . ' eV');
  $xdi   -> data($rdata);
  $xdi   -> export($outfile);
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
    printf $O "  %.3f  %.7f  %.7f  %.7f\n", @$p;
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

  my $counter = Term::Sk->new('Making map, time elapsed: %8t %15b (row %c of %m)',
			      {freq => 's', base => 0, target=>$self->rows});
  my $outfile = File::Spec->catfile($self->outfolder, $self->stub.'.map');
  my $maskfile = $self->mask_file("maskmap", 'gif');

  open(my $M, '>', $outfile);
  printf $M "# Energy calibration map for %s\n", $self->stub;
  printf $M "# Elastic energy range [%s : %s]\n", $energies[0], $energies[-1];
  print  $M "# ----------------------------------\n";
  print  $M "# row  column  interpolated_energy\n\n";
  my $ncols = $self->columns - 1;

  foreach my $r (0 .. $self->rows-1) {
    $counter->up if $self->screen;

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
  $counter->close if $self->screen;
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

See L<Xray::BLA>

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

This software was created with advice from and in collaboration with
Jeremy Kropf (kropf AT anl DOT gov)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2012 Bruce Ravel (bravel AT bnl DOT gov). All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
