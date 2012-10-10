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



sub mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{save}    || 0;
  $args{verbose} || 0;
  $args{animate} || 0;
  $args{write}    = 0;
  $args{write}    = 1 if ($args{animate} or $args{save});
  local $|=1;

  $self->clear_bad_pixel_list;
  $self->npixels(0);

  my $ret = $self->check;
  if ($ret->status == 0) {
    die $self->report($ret->message, 'bold red');
  };

  ## import elastic image and store basic properties
  my @out = ();
  $out[0] = ($args{write}) ? $self->mask_file("0", 'gif') : 0;
  $self->do_step('import_elastic_image', $out[0], $args{verbose}, 0);

  my $i=0;
  foreach my $st (@{$self->steps}) {
    my $set_npixels = ($st eq $self->steps->[-1]) ? 1 : 0;

    my @args = split(" ", $st);

    given ($args[0]) {		# see Xray::BLA::Mask
      when ('bad')  {
	$self -> bad_pixel_value($args[1]);
	$self -> weak_pixel_value($args[3]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('bad_pixels', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('multiply')  {
	$self->scalemask($args[2]);
	print $self->report("Multiply image by ".$self->scalemask, 'cyan') if $args{verbose};
	$self->elastic_image->inplace->mult($self->scalemask, 0);
      };

      when ('areal')  {
	$self->operation($args[1]);
	$self->radius($args[3]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('areal', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('lonely')  {
	$self->lonely_pixel_value($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('lonely_pixels', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('social')  {
	$self->social_pixel_value($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('social_pixels', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('entire') {
	print $self->report("Using entire image", 'cyan') if $args{verbose};
	$self->elastic_image(PDL::Core::ones($self->columns, $self->rows));
      };

      when ('map') {
	$self->deltae($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('mapmask', $out[-1], $args{verbose}, $set_npixels);
      };

      default {
	print report("I don't know what to do with \"$st\"", 'bold red');
      };
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
    my $fname = $self->mask_file("mask", 'gif');
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
  foreach my $pix (@{$self->bad_pixel_list}) {
    my $co = $pix->[0];
    my $ro = $pix->[1];
    ##print join("|", $co, $ro, $self->elastic_image->at($co, $ro)), $/;
    $self->elastic_image->($co, $ro) .= 0;
    $self->eimax($self->elastic_image->flat->max)
    ## for .=, see assgn in PDL::Ops
    ## for ->() syntax see PDL::NiceSlice
  };
};


## See Xray::BLA::Mask for the steps
sub do_step {
  my ($self, $step, $write, $verbose, $set_npixels) = @_;
  my $ret = $self->$step(write=>$write, unity=>$set_npixels);
  if ($ret->status == 0) {
    die $self->report($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $verbose;
  };
  $self->eimax($self->elastic_image->flat->max);
  $self->npixels($ret->status) if $set_npixels;
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
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} ||= 0;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $bpv   = $self->bad_pixel_value;
  my $wpv   = $self->weak_pixel_value;
  my $nrows = $self->rows - 1;

  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $nrows) {
      my $val = $ei->at($co, $ro);
      if ($val > $bpv) {
	$self->push_bad_pixel_list([$co,$ro]);
  	$ei -> ($co, $ro) .= 0;
	## for .=, see assgn in PDL::Ops
	## for ->() syntax see PDL::NiceSlice
  	++$removed;
  	++$off;
      } elsif ($val < $wpv) {
  	$ei -> ($co, $ro) .= 0;
  	++$toosmall;
  	++$off;
      } else {
  	if ($val) {++$on} else {++$off};
      };
    };
  };

  $self->nbad($removed);
  my $str = $self->report("Bad/weak step", 'cyan');
  $str   .= "\tRemoved $removed bad pixels and $toosmall weak pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub lonely_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} ||= 0;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $lpv   = $self->lonely_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($removed, $on, $off, $co, $ro, $cc, $rr) = (0,0,0);
  foreach my $co (0 .. $ncols) {
    foreach my $ro (0 .. $nrows) {

      ++$off, next if ($ei->at($co, $ro) == 0);

      my $count = 0;
    OUTER: foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc < 0));
	next if (($co == $ncols) and ($cc > 0));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr < 0));
	  next if (($ro == $nrows) and ($rr > 0));

	  ++$count if ($ei->at($co+$cc, $ro+$rr) != 0);
	};
      };
      if ($count < $lpv) {
	$ei -> ($co, $ro) .= 0;
	## for .=, see assgn in PDL::Ops
	## for ->() syntax see PDL::NiceSlice
	++$removed;
	++$off;
      } else {
	$ei -> ($co, $ro) .= 1 if ($args{unity});
	++$on;
      };
    };
  };

  my $str = $self->report("Lonely pixel step", 'cyan');
  $str   .= "\tRemoved $removed lonely pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub social_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $spv   = $self->social_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($added, $on, $off, $count, $co, $ro) = (0,0,0,0,0,0);
  my @addlist = ();
  my ($arg, $val) = (q{}, q{});
  foreach $co (0 .. $ncols) {
    foreach $ro (0 .. $nrows) {

      if ($ei->at($co, $ro) > 0) {
	++$on;
	$ei -> ($co, $ro) .= 1;
	next;
      }

      $count = 0;
    OUTER: foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc == -1));
	next if (($co == $ncols) and ($cc == 1));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr == -1));
	  next if (($ro == $nrows) and ($rr == 1));

	  ++$count if ($ei->at($co+$cc, $ro+$rr) != 0);
	  last OUTER if ($count > $spv);
	};
      };
      if ($count > $spv) {
	push @addlist, [$co, $ro];
	++$added;
	++$on;
      } else {
	++$off;
      };
    };
  };
  foreach my $px (@addlist) {
    $ei -> ($px->[0], $px->[1]) .= 1; # if ($args{unity});
    ## for .=, see assgn in PDL::Ops
    ## for ->() syntax see PDL::NiceSlice
  };
  $self->remove_bad_pixels;

  my $str = $self->report("Social pixel step", 'cyan');
  $str   .= "\tAdded $added social pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($on);
  $ret->message($str);
  return $ret;
};

sub mapmask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} ||= 0;
  my $ret = Xray::BLA::Return->new;

  my $maskfile = $self->mask_file("maskmap", 'gif');
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
  my ($self, @args) = @_;
  my %args = @args;
  my $ret = Xray::BLA::Return->new;

  $self->remove_bad_pixels;
  my $ei    = $self->elastic_image;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my @list = ();

  my ($removed, $on, $off, $co, $ro, $cc, $rr, $cdn, $cup, $rdn, $rup, $value) = (0,0,0,0,0,0,0,0,0,0,0,0);
  my $counter = q{};
  $counter = Term::Sk->new('Areal '.$self->operation.', time elapsed: %8t %15b (column %c of %m)',
			   {freq => 's', base => 0, target=>$ncols}) if $self->screen;

  my $radius = $self->radius;
  foreach my $co (0 .. $ncols) {
    $counter->up if $self->screen;
    $cdn = ($co < $radius)        ? 0      : $co-$radius;
    $cup = ($co > $ncols-$radius) ? $ncols : $co+$radius;
    foreach my $ro (0 .. $nrows) {

      $rdn = ($ro < $radius)        ? 0      : $ro-$radius;
      $rup = ($ro > $nrows-$radius) ? $nrows : $ro+$radius;
      my $slice = $ei->($cdn:$cup, $rdn:$rup);
      $value = ($self->operation eq 'median') ? $slice->flat->oddmedover : int($slice->flat->average);
      ## oddmedover, average: see PDL::Ufunc
      ## flat: see PDL::Core
      ## also see PDL::NiceSlice for matrix slicing syntax

      $value = 1 if (($value > 0) and ($args{unity}));
      push @list, [$co, $ro, $value];
      ($value > 0) ? ++$on : ++$off;
    };
  };
  $counter->close if $self->screen;
  foreach my $point (@list) {
    $ei -> ($point->[0], $point->[1]) .= $point->[2];
    ## for .=, see assgn in PDL::Ops
    ## for ->() syntax see PDL::NiceSlice
  };
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