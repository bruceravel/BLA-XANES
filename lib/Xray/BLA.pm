package Xray::BLA;
use Xray::BLA::Return;

use version;
our $VERSION = version->new('0.2');

use Moose;
use Moose::Util qw(apply_all_roles);

use MooseX::Aliases;
use MooseX::AttributeHelpers;

use File::Spec;

use vars qw($XDI_exists);
$XDI_exists = eval "require Xray::XDI" || 0;

eval 'use Term::ANSIColor ()';
eval { require Win32::Console::ANSI } if (($^O =~ /MSWin32/) and ($ENV{TERM} eq 'dumb'));

##with 'MooseX::MutatorAttributes';
##with 'MooseX::SetGet';		# this is mine....

has 'colored'		 => (is => 'rw', isa => 'Bool', default => 1);

has 'stub'		 => (is => 'rw', isa => 'Str', default => q{});
has 'scanfile'		 => (is => 'rw', isa => 'Str', default => q{});
has 'scanfile'		 => (is => 'rw', isa => 'Str', default => q{});
has 'scanfolder'	 => (is => 'rw', isa => 'Str', default => q{});
has 'tiffolder'		 => (is => 'rw', isa => 'Str', default => q{}, alias => 'tifffolder');
has 'outfolder'		 => (is => 'rw', isa => 'Str', default => q{},
			     trigger => sub{my ($self, $new) = @_;
					    mkpath($new) if not -d $new;
					  });

has 'energy'	         => (is => 'rw', isa => 'Int', default => 0, alias => 'peak_energy');
has 'columns'            => (is => 'rw', isa => 'Int', default => 0, alias => 'width');
has 'rows'               => (is => 'rw', isa => 'Int', default => 0, alias => 'height');

has 'bad_pixel_value'	 => (is => 'rw', isa => 'Int', default => 400);
has 'weak_pixel_value'	 => (is => 'rw', isa => 'Int', default => 3);
has 'lonely_pixel_value' => (is => 'rw', isa => 'Int', default => 3);
has 'social_pixel_value' => (is => 'rw', isa => 'Int', default => 2);
has 'npixels'            => (is => 'rw', isa => 'Int', default => 0);

has 'elastic_file'       => (is => 'rw', isa => 'Str', default => q{});

has 'bad_pixel_list' => (
			 metaclass => 'Collection::Array',
			 is        => 'rw',
			 isa       => 'ArrayRef',
			 default   => sub { [] },
			 provides  => {
				       'push'  => 'push_bad_pixel_list',
				       'pop'   => 'pop_bad_pixel_list',
				       'clear' => 'clear_bad_pixel_list',
				      }
			);
has 'mask_pixel_list' => (
			  metaclass => 'Collection::Array',
			  is        => 'rw',
			  isa       => 'ArrayRef',
			  default   => sub { [] },
			  provides  => {
					'push'  => 'push_mask_pixel_list',
					'pop'   => 'pop_mask_pixel_list',
					'clear' => 'clear_mask_pixel_list',
				       }
			 );

has 'backend'	    => (is => 'rw', isa => 'Str', default => q{});

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
  $self->clear_mask_pixel_list;

  my $ret = $self->check;
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red');
  };

  ## import elastic image and store basic properties
  my @out = ();
  $out[0] = ($args{write}) ? $self->mask_file("0", 'tif') : 0;
  $ret = $self->import_elastic_image(write=>$out[0]);
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## weed out bad and weak pixels
  $out[1] = ($args{write}) ? $self->mask_file("1", 'tif') : 0;
  $ret = $self->bad_pixels(write=>$out[1]);
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## weed out lonely pixels
  $out[2] = ($args{write}) ? $self->mask_file("2", 'tif') : 0;
  $ret = $self->lonely_pixels(write=>$out[2]);
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## include social pixels
  $out[3] = ($args{write}) ? $self->mask_file("3", 'tif') : 0;
  $ret = $self->social_pixels(write=>$out[3]);
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $args{verbose};
  };
  $self->npixels($ret->status);
  undef $ret;

  ## bad pixels may have been turned back on in the social pixel pass, so turn them off again
  foreach my $pix (@{$self->bad_pixel_list}) {
    my $co = $pix->[0];
    my $ro = $pix->[1];
    $self->set_pixel($self->elastic_image, $co, $ro, 0);
  };
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $self->rows-1) {
      next if ($self->get_pixel($self->elastic_image, $co, $ro) == 0);
      $self->push_mask_pixel_list([$co,$ro]);
    };
  };

  ## construct an animated gif of the mask building process
  if ($args{animate}) {
    my $fname = $self->animate(@out);
    print $self->assert("Wrote $fname", 'yellow'), "\n" if $args{verbose};
  };
  if ($args{save}) {
    my $fname = $self->mask_file("N", 'tif');
    print $self->assert("Saved stages of mask creation to $fname", 'yellow'), "\n" if $args{verbose};
  } else {
    unlink $_ foreach @out;
  };
};

sub check {
  my ($self) = @_;

  my $ret = Xray::BLA::Return->new;

  ## does elastic file exist?
  my $elastic = join("_", $self->stub, 'elastic', $self->energy).'_00001.tif';
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

  $self->backend('ImageMagick') if $self->backend eq 'Image::Magick';

  if (not $self->backend) {	# try Imager
    my $imager_exists       = eval "require Imager" || 0;
    $self->backend('Imager') if $imager_exists;
  };
  if (not $self->backend) {	# try Image::Magick
    my $image_magick_exists = eval "require Image::Magick" || 0;
    $self->backend('ImageMagick') if $image_magick_exists;
  };
  if (not $self->backend) {
    $ret->message("No BLA backend has been defined");
    $ret->status(0);
    return $ret;
  };

  eval {apply_all_roles($self, 'Xray::BLA::Backend::'.$self->backend)};
  if ($@) {
    $ret->message("BLA backend Xray::BLA::Backend::".$self->backend." could not be loaded");
    $ret->status(0);
    return $ret;
  };
  my $x = $self->read_image($self->elastic_file);
  $self->elastic_image($self->read_image($self->elastic_file));

  if (($self->backend eq 'Imager') and ($self->get_version($self->elastic_image) < 0.87)) {
    $ret->message("This program requires Imager version 0.87 or later.");
    $ret->status(0);
    return $ret;
  };
  if (($self->backend eq 'ImageMagick') and ($self->get_version($self->elastic_image) !~ m{Q32})) {
    $ret->message("The version of Image Magick on your computer does not support 32-bit depth.");
    $ret->status(0);
    return $ret;
  };

  return $ret;
};

sub import_elastic_image {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;

  my $ret = Xray::BLA::Return->new;

  $self->columns($self->get_columns($self->elastic_image));
  $self->rows($self->get_rows($self->elastic_image));
  my $str = $self->assert("\nProcessing ".$self->elastic_file, 'yellow');
  $str   .= sprintf "\tusing the %s backend\n", $self->backend;
  $str   .= sprintf "\t%d columns, %d rows, %d total pixels\n",
    $self->columns, $self->rows, $self->columns*$self->rows;
  $self->write_image($self->elastic_image, $args{write}) if $args{write};
  $ret->message($str);
  return $ret;
};

sub bad_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $bpv   = $self->bad_pixel_value;
  my $wpv   = $self->weak_pixel_value;
  my $nrows = $self->rows - 1;

  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $nrows) {
      my $val = $self->get_pixel($ei, $co, $ro);
      if ($val > $bpv) {
	$self->push_bad_pixel_list([$co,$ro]);
  	$self->set_pixel($ei, $co, $ro, 0);
  	++$removed;
  	++$off;
      } elsif ($val < $wpv) {
  	$self->set_pixel($ei, $co, $ro, 0);
  	++$toosmall;
  	++$off;
      } else {
  	if ($val) {++$on} else {++$off};
      };
    };
  };

  my $str = $self->assert("First pass", 'cyan');
  $str   .= "\tRemoved $removed bad pixels and $toosmall weak pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  if ($args{write}) {
    $self->write_image($ei, $args{write});
  };
  $ret->message($str);
  return $ret;
};

sub lonely_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $lpv   = $self->lonely_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($removed, $on, $off, $co, $ro, $cc, $rr) = (0,0,0);
  foreach my $co (0 .. $ncols) {
    foreach my $ro (0 .. $nrows) {

      ++$off, next if ($self->get_pixel($ei, $co, $ro) == 0);

      my $count = 0;
    OUTER: foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc == -1));
	next if (($co == $ncols) and ($cc == 1));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr == -1));
	  next if (($ro == $nrows) and ($rr == 1));

	  my $arg = sprintf("pixel[%d,%d]", $co+$cc, $ro+$rr);
	  ++$count if ($self->get_pixel($ei, $co+$cc, $ro+$rr) != 0);
	};
      };
      if ($count < $lpv) {
	$self->set_pixel($ei, $co, $ro, 0);
	++$removed;
	++$off;
      } else {
	++$on;
      };
    };
  };


  my $str = $self->assert("Second pass", 'cyan');
  $str   .= "\tRemoved $removed lonely pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  if ($args{write}) {
    $self->write_image($ei, $args{write});
  };
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

      ++$on, next if ($self->get_pixel($ei, $co, $ro) > 0);

      $count = 0;
    OUTER: foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc == -1));
	next if (($co == $ncols) and ($cc == 1));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr == -1));
	  next if (($ro == $nrows) and ($rr == 1));

	  ++$count if ($self->get_pixel($ei, $co+$cc, $ro+$rr) != 0);
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
    $self->set_pixel($ei, $px->[0], $px->[1], 5);
  };

  my $str = $self->assert("Third pass", 'cyan');
  $str   .= "\tAdded $added social pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  if ($args{write}) {
    $self->write_image($ei, $args{write});
  };
  $ret->status($on);
  $ret->message($str);
  return $ret;
};

sub mask_file {
  my ($self, $which, $type) = @_;
  $type ||= 'tif';
  my $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->energy, "mask_$which").'.');
  $fname .= $type;
  return $fname;
};


# # HERFD scan on Au3MarineCyanos1
# # ----------------------------------
# # energy time ring_current i0 it ifl ir roi1 roi2 roi3 roi4 tif
#     11850.000   20  95.3544291727  1400844   830935   653600   956465      38      18      15      46      1

sub scan {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{xdiini}  ||= q{};
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  my (@data, @point);

  print $self->assert("Reading scan from ".$self->scanfile, 'yellow');
  open(my $SCAN, "<", $self->scanfile);
  my $fname = join("_", $self->stub, $self->energy);
  $fname .= ($XDI_exists) ? '.xdi' : '.dat';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);
  while (<$SCAN>) {
    next if m{\A\#};
    next if m{\A\s*\z};
    chomp;
    @point = ();
    my @list = split(" ", $_);

    my $ret = $self->apply_mask($list[11], verbose=>$args{verbose});
    push @point, $list[0];
    push @point, $ret->status/$list[3];
    push @point, @list[3..6];
    push @point, $ret->status;
    push @point, @list[1..2];
    push @data, [@point];
  };
  close $SCAN;

  if (($XDI_exists) and (-e $args{xdiini})) {
    my $xdi = Xray::XDI->new();
    $xdi   -> ini($args{xdiini});
    $xdi   -> push_comment("HERFD scan on " . $self->stub);
    $xdi   -> push_comment(sprintf("%d illuminated pixels (of %d) in the mask", $self->npixels, $self->columns*$self->rows));
    $xdi   -> data(\@data);
    $xdi   -> export($outfile);
  } else {
    open(my $O, '>', $outfile);
    print   $O "# HERFD scan on " . $self->stub . $/;
    printf  $O "# %d illuminated pixels (of %d) in the mask\n", $self->npixels, $self->columns*$self->rows;
    print   $O "# -------------------------\n";
    print   $O "#   energy      mu           i0           it          ifl         ir          herfd   time    ring_current\n";
    foreach my $p (@data) {
      printf $O "  %.3f  %.7f  %10d  %10d  %10d  %10d  %10d  %4d  %8.3f\n", @$p;
    };
    close   $O;
  };

  print $self->assert("Wrote $outfile", 'bold green');
  return $ret;
};


sub apply_mask {
  my ($self, $tif, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  my $fname = sprintf("%s_%5.5d.tif", $self->stub, $tif);
  my $image = File::Spec->catfile($self->tiffolder, $fname);
  if (not -e $image) {
    warn "\tskipping $image, file not found\n";
    $ret->message("skipping $image, file not found\n");
    $ret->status(0);
  } elsif (not -r $image) {
    warn "\tskipping $image, file cannot be read\n";
    $ret->message("skipping $image, file cannot be read\n");
    $ret->status(0);
  } else {
    printf("  %3d, %s", $tif, $image) if ($args{verbose} and (not $tif % 10));

    my $datapoint = $self->read_image($image);
    my $sum = 0;

    foreach my $pix (@{$self->mask_pixel_list}) {
      $sum += $self->get_pixel($datapoint, $pix->[0], $pix->[1]);
    };

    printf("  %7d\n", $sum) if ($args{verbose} and (not $tif % 10));
    $ret->status($sum);
  };
  return $ret;
};


sub assert {
  my ($self, $message, $color) = @_;
  my $string = ($self->colored) ? Term::ANSIColor::colored($message, $color) : $message;
  return $string.$/;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Xray::BLA - Convert bent-Laue analyzer + Pilatus 100K data to a XANES spectrum

=head1 VERSION

0.2

=head1 SYNOPSIS

   my $spectrum = Xray::BLA->new;

   $spectrum->scanfolder('/path/to/scanfolder');
   $spectrum->tiffolder('/path/to/tiffolder');
   $spectrum->outfolder('/path/to/outfolder');
   $spectrum->stub('myscan');
   $spectrum->energy(9713);

   $spectrum->mask(verbose=>1, write=>0, animate=>0);
   $spectrum->scan(verbose=>1);

=head1 DESCRIPTION

This module is an engine for converting a series of tiff images
collected using a bent Laue analyzer and a Pilatus 100K area detector
into a high energy resolution XANES spectrum.  A HERFD measurement
consists of a related set of files from the measurement:

=over

=item 1.

A column data file containing the energy, signals from other scalars,
and a few other columns

=item 2.

A tif image of an exposure at each energy point.  This image must be
interpreted to be the HERFD signal at that energy point.

=item 3.

A set of one or more exposures taken at incident energies around the
peak of the fluorescence line (e.g. Lalpha1 for an L3 edge, etc).
These exposures are used to make masks for interpreting the sequence
of images at each energy point.

=back

As you can see in the synopsis, there are attributes for specifying
the paths to the locations of the column data files (C<scanfolder>)
and the tiff files (C<tiffolder>, C<tifffolder> with 3 C<f>'s is an
alias)).

Assumptions are made about the names of the files in those
locations. Each files is build upon a stub, indicated by the C<stub>
attribute.  If C<stub> is "Aufoil", then the column data in
C<scanfolder> file is named F<Aufoil.001>.  The tiff images at each
energy point are called F<Aufoil_NNNNN.tif> where C<NNNNN> is the
index of the energy point.  One of the columns in the scan file
contains this index so it is unambiguous which tiff image corresponds
to which energy point.  Finally, the elastic exposures are called
F<Aufoil_elastic_EEEE_00001.tif> where C<EEEE> is the incident
energy. For instance, an exposure at the peak of the gold Lalpha1 line
would be called F<Aufoil_elastic_9713_00001.tif>.

If you use a different naming convention, this software in its current
form B<will break>!

This software uses an image handling back to interact with these two
sets of tiff images.  Since the Pilatus writes rather unusual tiff
files with signed 32 bit integer samples, not every image handling
package can deal gracefully with them.  I have found two choices in
the perl universe that work well, L<Imager> and C<Image::Magick>,
although using L<Image::Magick> requires recompiliation to be able to
use 32 bit sample depth.  Happily, I<Imager> works out of the box.
The default is to use L<Imager>. but this can be specified using the
C<backend> attribute when the Xray::BLA object is created.

=head1 ATTRIBUTES

=over 4

=item C<backend>

Specify which image handling library to use.  Currently the possible
values for this attribute are C<Imager> and C<ImageMagick>.  The
default, if not specified, is to use L<Imager>.  See the compilation
caveat below if you choose to use L<Image::Magick> instead.
L<Imager>, on the other hand, should just work out of the box.

=item C<stub>

The basename of the scan and image files.  The scan file is called
C<E<lt>stubE<gt>.001>, the image files are called
C<E<lt>stubE<gt>_NNNNN.tif>, and the processed column data files are
called C<E<lt>stubE<gt>_E<lt>energyE<gt>.001>.

=item C<scanfile>

The fully resolved path to the scan file, as determined from C<stub>
and C<scanfolder>.

=item C<scanfolder>

The folder containing the scan file.  The scan file name is
constructed from the value of C<stub>.

=item C<tiffolder>

The folder containing the image files.  The image file names are
constructed from the value of C<stub>.

=item C<tiffolder>

The folder to which the processed file is written.  The processed file
name is constructed from the value of C<stub>.

=item C<energy>

This normally takes the tabulated value of the measured fluorescence
line.  For example, for the the gold L3 edge experiment, the L alpha 1
line is likely used.  It's tabulated value is 9715 eV.

The image containing the data measured from the elastic scattering
with the incident energy at this energy will have a filename something
like F<E<lt>stubE<gt>_elsatic_E<lt>energyE<gt>_00001.tif>.

This value can be changed to some other measured elastic energy in
order to scan the off-axis portion of the spectrum.

C<peak_energy> is an alias for C<energy>.

=item C<bad_pixel_value>  [500]

In the first pass over the elastic image, spuriously large pixel
values -- presumably indicating the locations of bad pixels -- are
removed from the image by setting them to 0.  This is the cutoff value
above which a pixel is assumed to be a bad one.

=item C<weak_pixel_value> [3]

In the first pass over the elastic image, small valued pixels are
removed from the image.  These pixels are presumed to have been
illuminated by a small number of stray photons not associated with the
imagining of photons at the peak energy.  Pixels with fewer than this
n umber of counts are set to 0.

=item C<lonely_pixel_value> [3]

In the second pass over the elastic image, illuminiated pixles with
fewer than this number of illuminated neighboring pixels are removed
fropm the image.  This serves the prupose of removing most stray
pixels not associated with the main image of the peak energy.

=item C<social_pixel_value> [2]

In the third pass over the elastic image, dark pixels which are
surrounded by larger than this number of illuminated pixels are
presumed to be a part of the image of the peak energy.  They are given
a value of 5 counts.  This serves the prupose of making the elastic
image a solid mask with few gaps in the image of the main peak.

=item C<elastic_file>

This contains the name of the elastic image file.  It is constructed
from the values of C<stub>, C<energy>, and C<tiffolder>.

=item C<elastic_image>

This contains the backend object corresponding to the elastic image.

=item C<npixels>

The number of illuminated pixels in the mask.  That is, the number of
pixels contributing to the HERFD signal.

=item C<columns>

When the elastic file is read, this is set with the number of columns
in the image.  All images in the measurement are presumed to have the
same number of columns.  C<width> is an alias for C<columns>.

=item C<rows>

When the elastic file is read, this is set with the number of rows in
the image.  All images in the measurement are presumed to have the
same number of rows.  C<height> is an alias for C<rows>.

=back

=head1 METHODS

All methods return an object of type C<Xray::BLA::Return>.  This
object has two attributes: C<status> and C<message>.  A successful
return will have a positive definite C<status>.  Any reporting (for
example exception reporting) is done via the C<message> attribute.

Some methods, for example C<apply_mask>, use the return C<status> as
the sum of HERFD counts from the illuminated pixels.

=head2 API

=over 4

=item C<mask>

Create a mask from the elastic image measured at the energy given by
C<energy>.

  $spectrum->mask(verbose=>0, save=>0, animate=>0);

When true, the C<verbose> argument causes messages to be printed to
standard output with information about each stage of mask creation.

When true, the C<save> argument causes a tif file to be saved at
each stage of processing the mask.

When true, the C<animate> argument causes a properly scaled animation
to be written showing the stages of mask creation.

Currently, these output image files are signed 32 bit tiff images or
animations.  Not many image handling applications will handle them.  I
recommend ImageJ or the specially modified Image Magick, if you have
it.

=item C<scan>

Rewrite the scan file with a column containing the HERFD signal as
computed by applying the mask to the image file from each data point.

  $spectrum->scan(verbose=>0, xdiini=>$inifile);

When true, the C<verbose> argument causes messages to be printed to
standard output about every data point being processed.

The C<xdiini> argument takes the filename of an ini-style
configuration file for XDI metadata.  If no ini file is supplied, then
no metadata and no column labels will be written to the output file.

=back

=head2 Internal methods

All of these methods return a L<Xray::BLA::Return> object, which has
two attributes, and integer C<status> to indicate the return status (1
is normal in all cases here) and an string C<message> containing a
short description of the exception (an empty string indicates no
exception).

=over 4

=item C<check>

Confirm that the scan file and elastic image taken from the values of
C<stub> and C<energy> exist and can be read.  Import an imaging
backend and perform checks to make sure that it can support the 32 bit
tiff images.

This is the first thing done by the C<mask> method and must be the
initial chore of any script using this library.

  $spectrum -> check;

=item C<import_elastic_image>

Import the file containing the elastic image and perform the first
pass in which bad pixels and weak pixels are removed from the image.

  $spectrum -> import_elastic_image;

The intermediate image can be saved:

  $spectrum -> import_elastic_image(write => "firstpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

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

=item C<apply_mask>

Apply the mask to the image for a given data point to obtain the HERFD
signal for that data point.

  $spectrum -> apply_mask($tif_number, verbose=>1)

The C<status> of the return object contains the photon count from the
image for this data point.

=back

=head1 ERROR HANDLING

If the scan file or the eleastic image cannot be found or cannot be
read, a program will die with a message to STDERR to that effect.

If an image file corresponding to a data point cannot be found or
cannot be read, a value of 0 will be written to the output file for
that data point and a warning will be printed to STDOUT.

Any warning or error message will contain the complete file name so
that the file naming or configuration mistake can be tracked down.

Errors interpreting the contents of an image file are probably not
handled well.

The output column data file is B<not> written on the fly, so a run
that dies or is halted early will result in no output being written.
The save and animation images are written at the time the message is
written to STDOUT when the C<verbose> switch is on.

=head1 CONFIGURATION AND ENVIRONMENT

Using the scripts in the F<bin/> directory, file locations, elastic
energies, and mask parameters are specified in an ini-style
configuration file.  An example is found in F<share/config.ini>.

If using L<Xray::XDI>, metadata can be supplied by an ini-style file.
And example is found in F<share/bla.xdi.ini>.

=head1 DEPENDENCIES

=head2 CPAN

=over 4

=item *

L<Moose>

=item *

L<MooseX::Aliases>

=item *

Math::Round

=item *

Config::IniFiles

=item *

L<Imager> or L<Image::Magick>

=item *

L<Xray::XDI>  (optional)

=back

=head2 Image Magick

As delivered to an Ubuntu system, Image Magick cannot handle the TIFF
files as written by the Pilatus 100K imagine detector.  In order to be
able to use Image Magick, it must be recompiled with a larger bit
depth.  This is done by downloading and unpacking the tarball, then
doing

      ./configure --with-quantum-depth=32

I also rebuilt the perl wrapper which comes with the Image Magick
source code.  This also was a bit tricky.  My Ubuntu system has perl
5.10.1 and therefore has a F<libperl.5.10.1.so>.  It did not, however,
have a F<libperl.so> symlinked to it.  To get the perl wrapper to
build, I had to do

      sudo ln -s /usr/lib/libperl.so.5.10.1 /usr/lib/libperl.so

Adjust the version number on the perl library as needed.

I have not been able to rebuild Image::Magick with Windows and
MinGW. Happily C<Imager> works out of the box with MinGW and
Strawberry Perl.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

assigned the median pixel value within a particular radius to each point

=item *

bin with 2x2 or 3x3 bins

=item *

write images and animations to gif files

=item *

Other possible backends: PDL, Graphics::Magick, GD.  PDL might be
faster....

=item *

Interpolate elastic masks to make a pixel v energy map for more
fine-grained intepretation of the data images

=item *

MooseX::MutatorAttributes or MooseX::GetSet would certainly be nice....

=item *

In the future, will need a more sophisticated mechanism for relating
C<stub> to scan file and to image files -- some kind of templating
scheme, I suspect

=back


Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

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
