package Xray::BLA::Mask;


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

use feature 'switch';

use Moose::Role;
use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);
use PDL::IO::Dumper;
use PDL::Image2D;


sub mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{unity}    ||= 0;
  $args{pass}     ||= 0;
  $args{vertical} ||= 0;
  $args{save}     ||= 0;
  $args{verbose}  ||= 0;
  $args{animate}  ||= 0;
  $args{plot}     ||= 0;
  $args{write}      = 0;
  $args{write}      = 1 if ($args{animate} or $args{save});
  local $|=1;

  #$self->clear_bad_pixel_list;
  $self->bad_pixel_mask(PDL::null);
  $self->npixels(0);

  my $ret = $self->check;
  if ($ret->status == 0) {
    die $self->report($ret->message, 'bold red');
  };

  ## import elastic image and store basic properties
  my @out = ();
  $out[0] = ($args{write}) ? $self->mask_file("0", $self->outimage) : 0;

  $args{write}   = $out[0];
  $args{verbose} = $args{verbose};
  $args{unity}   = 0;
  $self->do_step('import_elastic_image', %args);

  my $i=0;
  foreach my $st (@{$self->steps}) {
    my $set_npixels = ($st eq $self->steps->[-1]) ? 1 : 0;

    my @args = split(" ", $st);

    $args{write}   = $out[-1];
    $args{verbose} = $args{verbose};
    $args{unity}   = $set_npixels;

  STEPS: {
      ($args[0] eq 'bad') and do {
	$self -> bad_pixel_value($args[1]);
	$self -> weak_pixel_value($args[3]);
	push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
	$self->do_step('bad_pixels', %args);
	last STEPS;
      };

      ($args[0] eq 'multiply') and do  {
	$self->scalemask($args[2]);
	push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
	$self->do_step('multiply', %args);
	last STEPS;
      };

      ($args[0] eq 'areal') and do  {
	$self->operation($args[1]);
	$self->radius($args[3]);
	push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
	$self->do_step('areal', %args);
	last STEPS;
      };

      ($args[0] eq 'lonely') and do  {
	$self->lonely_pixel_value($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
	$self->do_step('lonely_pixels', %args);
	last STEPS;
      };

      ($args[0] eq 'social') and do  {
	$self->social_pixel_value($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
	$self->do_step('social_pixels', %args);
	last STEPS;
      };

      ($args[0] eq 'entire') and do {
	print $self->report("Using entire image", 'cyan') if $args{verbose};
	$self->elastic_image(PDL::Core::ones($self->columns, $self->rows));
	last STEPS;
      };

      ($args[0] eq 'map') and do {
	$self->deltae($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
	$self->do_step('mapmask', %args);
	last STEPS;
      };

      print report("I don't know what to do with \"$st\"", 'bold red');
    };
  };

  ## bad pixels may have been turned back on in the social, areal, or entire pass, so turn them off again
  $self->remove_bad_pixels;

  ## construct an animated gif of the mask building process
  if ($args{animate}) {
    my $fname = $self->animate('anim', @out);
    print $self->report("Wrote $fname", 'yellow'), "\n" if $args{verbose};
  };
  if ($args{save}) {
    my $fname = $self->mask_file("mask", $self->outimage);
    $self->elastic_image->wim($fname);
    print $self->report("Saved mask to $fname", 'yellow'), "\n" if $args{verbose};
  };
  unlink $_ foreach @out;

};



##################################################################################
## mask creation utilities
##################################################################################

sub check {
  my ($self) = @_;

  my $ret = Xray::BLA::Return->new;

  ## does elastic file exist?
  my $elastic = join("_", $self->stub, 'elastic', $self->energy, $self->tiffcounter).'.tif';
  $self->elastic_file(File::Spec->catfile($self->tiffolder, $elastic));
  if (not -e $self->elastic_file) {
    $ret->message("Elastic image file \"".$self->elastic_file."\" does not exist");
    $ret->status(0);
    return $ret;
  };
  if (not -r $self->elastic_file) {
    $ret->message("Elastic image file \"".$self->elastic_file."\" cannot be read");
    $ret->status(0);
    return $ret;
  };

  ## does scan file exist?
  my $scanfile = File::Spec->catfile($self->scanfolder, $self->stub.'.001');
  $self->scanfile($scanfile);
  if (not -e $scanfile) {
    $ret->message("Scan file \"$elastic\" does not exist");
    $ret->status(0);
    return $ret;
  };
  if (not -r $scanfile) {
    $ret->message("Scan file \"$elastic\" cannot be read");
    $ret->status(0);
    return $ret;
  };

  # $self->backend('ImageMagick') if $self->backend eq 'Image::Magick';
  # if (not $self->backend) {	# try Imager
  #   my $imager_exists       = eval "require Imager" || 0;
  #   $self->backend('Imager') if $imager_exists;
  # };
  # if (not $self->backend) {	# try Image::Magick
  #   my $image_magick_exists = eval "require Image::Magick" || 0;
  #   $self->backend('ImageMagick') if $image_magick_exists;
  # };
  # if (not $self->backend) {
  #   $ret->message("No BLA backend has been defined");
  #   $ret->status(0);
  #   return $ret;
  # };

  # eval {apply_all_roles($self, 'Xray::BLA::Backend::'.$self->backend)};
  # if ($@) {
  #   $ret->message("BLA backend Xray::BLA::Backend::".$self->backend." could not be loaded");
  #   $ret->status(0);
  #   return $ret;
  # };

  my $img = Xray::BLA::Image->new(parent=>$self);
  $self->elastic_image($img->Read($self->elastic_file));

  if (($self->backend eq 'Imager') and ($self->get_version < 0.87)) {
    $ret->message("This program requires Imager version 0.87 or later.");
    $ret->status(0);
    return $ret;
  };
  if (($self->backend eq 'ImageMagick') and ($self->get_version !~ m{Q32})) {
    $ret->message("The version of Image Magick on your computer does not support 32-bit depth.");
    $ret->status(0);
    return $ret;
  };

  return $ret;
};

sub remove_bad_pixels {
  my ($self) = @_;
  $self->elastic_image->inplace->mult(1-$self->bad_pixel_mask,0);
  # foreach my $pix (@{$self->bad_pixel_list}) {
  #   my $co = $pix->[0];
  #   my $ro = $pix->[1];
  #   ##print join("|", $co, $ro, $self->elastic_image->at($co, $ro)), $/;
  #   $self->elastic_image->($co, $ro) .= 0;
  #   $self->eimax($self->elastic_image->flat->max)
  #   ## for .=, see assgn in PDL::Ops
  #   ## for ->() syntax see PDL::NiceSlice
  # };
};


## See Xray::BLA::Mask for the steps
sub do_step {
  my ($self, $step, @args) = @_;
  my %args = @args;
  my $ret = $self->$step(\%args);
  if ($ret->status == 0) {
    die $self->report($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $args{verbose};
  };
  $self->eimax($self->elastic_image->flat->max);
  $self->npixels($ret->status) if $args{unity};

  if ($args{plot}) {
    my $save = $self->prompt;
    $self->prompt('        Hit return to plot the next step>');
    my $cbm = int($self->elastic_image->max);
    if ($cbm < 1) {
      $cbm = 1;
    } elsif ($cbm > $self->bad_pixel_value/10) {
      $cbm = $self->bad_pixel_value/10;
    };
    $self->cbmax($cbm);# if $step =~ m{social};
    $self->plot_mask;
    $self->pause(-1);
    $self->prompt($save);
  };

  undef $ret;
  return 1;
};


##################################################################################
## mask creation steps
##   bad pixels: note and remove spuriously large pixels from the image
##   lonely: remove illuminated pixels that are surrouned by too few illuminated pixels
##   social: include dark pixels that are surrounded by enough illuminated pixels
##   mapmask: make a mask from a previously calculated energy map
##   areal: average pixel count over a square with a count cut-off
##################################################################################

sub bad_pixels {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $bpv   = $self->bad_pixel_value;
  my $wpv   = $self->weak_pixel_value;
  my $nrows = $self->rows - 1;

  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  my $bad  = $ei->gt($bpv,0);	# mask of bad pixels
  my $weak = $ei->lt($wpv,0);	# mask of weak pixels
  $self->nbad($bad->sum);
  $ei  = $ei * (1-$bad) * (1-$weak); # remove bad and weak pixels
  $on  = $ei->gt(0,0)->sum;
  $off = $ei->eq(0,0)->sum;
  $self->elastic_image($ei);
  $self->bad_pixel_mask($bad);

  my $str = $self->report("Bad/weak step", 'cyan');
  $str   .= sprintf "\tRemoved %d bad pixels and %d weak pixels\n", $self->nbad, $weak->sum;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub multiply {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  $self->elastic_image->inplace->mult($self->scalemask, 0);

  my $str = $self->report("Multiply image by ".$self->scalemask, 'cyan');
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;

};

sub lonely_pixels {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $lpv   = $self->lonely_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;


  my ($h,$w) = $ei->dims;
  my $onoff = $ei->gt(0,0);
  my $before = $onoff->sum;
  ## this simple convolution will measure the number of neighbors
  my $smoothed = $onoff->conv2d(PDL::Core::ones(3,3), {Boundary => 'Truncate'});

  ## set pixels smaller than $lpv to 0
  $ei->inplace->mult(1-$smoothed->le($lpv,0),0);
  $self->elastic_image($ei);

  my $onval  = $ei->gt(0,0)->sum;
  my $offval = $h*$w-$onval;

  my $str = $self->report("Lonely pixel step", 'cyan');
  $str   .= sprintf "\tRemoved %d lonely pixels\n", $before - $onval;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $onval, $offval, $onval+$offval;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub social_pixels {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $spv   = $self->social_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;


  my $onoff = $ei->gt(0,0);
  my $before = $onoff->sum;
  my $kernel = PDL::Core::ones(3,3);
  if ($args{vertical}) {
    $kernel->(0,:) .= 0.001;
    $kernel->(2,:) .= 0.001;
    ## rotate this matrix if the shadows are not perpendicular
  };
  my $smoothed = $onoff->conv2d($kernel, {Boundary => 'Truncate'});


  my ($h,$w) = $ei->dims;
  my $on  = $smoothed->gt($spv,0);
  my $onval  = $on->sum;
  my $offval = $h*$w-$onval;
  $self->elastic_image($on);

  # my ($added, $on, $off, $count, $co, $ro) = (0,0,0,0,0,0);
  # my @addlist = ();
  # my ($arg, $val) = (q{}, q{});
  # foreach $co (0 .. $ncols) {
  #   foreach $ro (0 .. $nrows) {

  #     if ($ei->at($co, $ro) > 0) {
  # 	++$on;
  # 	$ei -> ($co, $ro) .= 1;
  # 	next;
  #     }

  #     $count = 0;
  #   OUTER: foreach my $cc (-1 .. 1) {
  # 	next if (($co == 0) and ($cc == -1));
  # 	next if (($co == $ncols) and ($cc == 1));
  # 	foreach my $rr (-1 .. 1) {
  # 	  next if (($cc == 0) and ($rr == 0));
  # 	  next if (($ro == 0) and ($rr == -1));
  # 	  next if (($ro == $nrows) and ($rr == 1));

  # 	  ++$count if ($ei->at($co+$cc, $ro+$rr) != 0);
  # 	  last OUTER if ($count > $spv);
  # 	};
  #     };
  #     if ($count > $spv) {
  # 	push @addlist, [$co, $ro];
  # 	++$added;
  # 	++$on;
  #     } else {
  # 	++$off;
  #     };
  #   };
  # };
  # foreach my $px (@addlist) {
  #   $ei -> ($px->[0], $px->[1]) .= 1; # if ($args{unity});
  #   ## for .=, see assgn in PDL::Ops
  #   ## for ->() syntax see PDL::NiceSlice
  # };
  $self->remove_bad_pixels;

  my $text = $args{pass} ? " (pass ".$args{pass}.")" : q{};
  my $str = $self->report("Social pixel step$text", 'cyan');
  $str   .= sprintf "\tAdded %d social pixels\n", $onval-$before;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $onval, $offval, $onval+$offval;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($onval);
  $ret->message($str);
  return $ret;
};

sub convert_to_and {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $spv   = $self->social_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($added, $on, $off, $count, $co, $ro) = (0,0,0,0,0,0);
  foreach $co (0 .. $ncols) {
    foreach $ro (0 .. $nrows) {
      if ($ei->at($co, $ro) > 0) {
	++$on;
	$ei -> ($co, $ro) .= 1;
      } else {
	++$off;
      };
    };
  };
  $self->remove_bad_pixels;

  my $str = $self->report("Convert to AND mask", 'cyan');
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($on);
  $ret->message($str);
  return $ret;
};

sub row_normalize {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($added, $on, $off, $count, $co, $ro) = (0,0,0,0,0,0);
  foreach $ro (0 .. $nrows) {
    my $rownorm = $ei->(:,$ro)->sum;
    #my ($bins, $pops) = $ei->(:,$ro)->hist(0, $rownorm, $rownorm/6);
    #my $cutoff = $bins->(3); #($bins->(2) - $bins(1)) / 2;
    foreach $co (0 .. $ncols) {
      if ($ei->at($co, $ro) > 0) {
	$ei -> ($co, $ro) .=  $ei -> ($co, $ro) / $rownorm;
    	#$ei -> ($co, $ro) .= 1;
    	++$on;
      } else {
    	#$ei -> ($co, $ro) .= 0;
    	++$off;
      };
    };
  };

  my $str = $self->report("Row normalize", 'cyan');
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($on);
  $ret->message($str);
  return $ret;
};

sub mapmask {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  my $maskfile = $self->mask_file("maskmap", $self->outimage);
  if (not -e $maskfile) {
    $ret->status(0);
    $ret->message("The energy map file $maskfile does not exist.");
    return $ret
  };
  if (not -r $maskfile) {
    $ret->status(0);
    $ret->message("The energy map file $maskfile cannot be read.");
    return $ret
  };
  my $image = frestore($maskfile);
  $self -> elastic_image($image);
  $self -> elastic_image->inplace->minus($self->energy,0);
  $self -> elastic_image->inplace->abs;
  $self -> elastic_image->inplace->lt($self->deltae,0);
  $self -> remove_bad_pixels;

  my $on  = $self->elastic_image->flat->sumover->sclr;
  my $off = $self->columns*$self->rows - $on;
  my $str = $self->report("Energy map step", 'cyan');
  $str   .= sprintf "\tUsing pixels within %.2f eV of %.1f eV\n", $self->deltae, $self->energy;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;

  $self->elastic_image->wim($args{write}) if $args{write};

  $ret->status($on);
  $ret->message($str);
  return $ret;

};

sub areal {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  $self->remove_bad_pixels;
  my $ei    = $self->elastic_image;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my @list = ();

  #my ($removed, $on, $off, $co, $ro, $cc, $rr, $cdn, $cup, $rdn, $rup, $value) = (0,0,0,0,0,0,0,0,0,0,0,0);
  my $counter = q{};
  #$counter = Term::Sk->new('Areal '.$self->operation.', time elapsed: %8t %15b (column %c of %m)',
#			   {freq => 's', base => 0, target=>$ncols}) if $self->screen;

  my ($h,$w) = $ei->dims;

  my $before = $ei->gt(0,0)->sum;
  my $radius = $self->radius;
  my $kernel = PDL::Core::ones(2*$radius+1,2*$radius+1) / (2*$radius+1)**2;
  my $smoothed = $ei->conv2d($kernel, {Boundary => 'Truncate'});
  $smoothed = $smoothed->gt(1,0);
  my $on = $smoothed->sum;
  my $off = $h*$w - $on;

#  my $radius = $self->radius;
  # foreach my $co (0 .. $ncols) {
  #   $counter->up if $self->screen;
  #   $cdn = ($co < $radius)        ? 0      : $co-$radius;
  #   $cup = ($co > $ncols-$radius) ? $ncols : $co+$radius;
  #   foreach my $ro (0 .. $nrows) {

  #     $rdn = ($ro < $radius)        ? 0      : $ro-$radius;
  #     $rup = ($ro > $nrows-$radius) ? $nrows : $ro+$radius;
  #     my $slice = $ei->($cdn:$cup, $rdn:$rup);
  #     $value = ($self->operation eq 'median') ? $slice->flat->oddmedover : int($slice->flat->average);
  #     ## oddmedover, average: see PDL::Ufunc
  #     ## flat: see PDL::Core
  #     ## also see PDL::NiceSlice for matrix slicing syntax

  #     $value = 1 if (($value > 0) and ($args{unity}));
  #     push @list, [$co, $ro, $value];
  #     ($value > 0) ? ++$on : ++$off;
  #   };
  # };
  # $counter->close if $self->screen;
  # foreach my $point (@list) {
  #   $ei -> ($point->[0], $point->[1]) .= $point->[2];
  #   ## for .=, see assgn in PDL::Ops
  #   ## for ->() syntax see PDL::NiceSlice
  # };
  $self->elastic_image($ei*$smoothed);
  $self->remove_bad_pixels;

  my $str = $self->report("Areal ".$self->operation." step", 'cyan');
  my $n = 2*$self->radius+1;
  $str   .= "\tSet each pixel to the ".$self->operation." value of a ${n}x$n square centered at that pixel\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}, {COLOR=>'bw'}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($on);
  $ret->message($str);
  return $ret;
};



1;

=head1 NAME

Xray::BLA::Mask - Role containing mask creation steps

=head1 VERSION

See L<Xray::BLA>

=head1 METHODS

=over 4

=item C<mask>

Create a mask from the elastic image measured at the energy given by
C<energy>.

  $spectrum->mask(verbose=>0, save=>0, animate=>0);

When true, the C<verbose> argument causes messages to be printed to
standard output with information about each stage of mask creation.

When true, the C<save> argument causes a tif file to be saved at each
stage of processing the mask.

When true, the C<animate> argument causes a properly scaled animation
to be written showing the stages of mask creation.

These output image files are gif.

This method is a wrapper around the contents of the C<step> attribute.
Each entry in C<step> will be parsed and executed in sequence.

=item C<lonely_pixels>

Make the second pass over the elastic image.  Remove illuminated
pixels which are not surrounded by enough other illuminated pixels.

  $spectrum -> lonely_pixels;

The intermediate image can be saved:

  $spectrum -> lonely_pixels(write => "secondpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=item C<social_pixels>

Make the third pass over the elastic image.  Include dark pixels which
are surrounded by enough illuminated pixels.

  $spectrum -> lonely_pixels;

The final mask image can be saved:

  $spectrum -> lonely_pixels(write => "finalpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=item C<areal>

At each point in the mask, assign its value to the median or mean
value of a square centered on that point.  The size of the square is
determined by the value of the C<radius> attribute.

  $spectrum -> areal;

The final mask image can be saved:

  $spectrum -> areal(write => "arealpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=back

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
