package Xray::BLA;
use Xray::BLA::Return;

use version;
our $VERSION = version->new('0.1');

use Moose;
use MooseX::Aliases;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;

use Image::Magick;

with 'MooseX::SetGet';		# this is mine....

has 'stub'       => (is => 'rw', isa => 'Str',     default => q{});
has 'scanfile'   => (is => 'rw', isa => 'Str',     default => q{});
has 'scanfolder' => (is => 'rw', isa => 'Str',     default => q{});
has 'tiffolder'  => (is => 'rw', isa => 'Str',     default => q{});
has 'outfolder'  => (is => 'rw', isa => 'Str',     default => q{});

has 'peak_energy' => (is => 'rw', isa => 'Int',   default => 0);

has 'bad_pixel_value'  => (is => 'rw', isa => 'Int',      default => 500);
has 'weak_pixel_value' => (is => 'rw', isa => 'Int',      default => 3);
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

has 'lonely_pixel_value' => (is => 'rw', isa => 'Int',    default => 3);
has 'social_pixel_value' => (is => 'rw', isa => 'Int',    default => 2);

has 'elastic_file'  => (is => 'rw', isa => 'Str',   default => q{});
has 'elastic_image' => (is => 'rw', isa => 'Image::Magick');
has 'elastic_mask'  => (is => 'rw', isa => 'Image::Magick');

has 'columns'  => (is => 'rw', isa => 'Int',   default => 0);
has 'rows'     => (is => 'rw', isa => 'Int',   default => 0);


sub mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write}   || 0;
  $args{verbose} || 0;
  $args{animate} || 0;

  ## import elastic image and store basic properties
  my @out = ();
  $out[0] = ($args{write}) ?
    File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_0").'.tif') : 0;
  my $ret = $self->import_elastic_image(write=>$out[0]);
  if ($ret->status == 0) {
    print $ret->message;
    die;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## weed out bad and weak pixels
  $out[1] = ($args{write}) ?
    File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_1").'.tif') : 0;
  $ret = $self->bad_pixels(write=>$out[1]);
  if ($ret->status == 0) {
    print $ret->message;
    die;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## weed out lonely pixels
  $out[2] = ($args{write}) ?
    File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_2").'.tif') : 0;
  $ret = $self->lonely_pixels(write=>$out[2]);
  if ($ret->status == 0) {
    print $ret->message;
    die;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## include social pixels
  $out[3] = ($args{write}) ?
    File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_3").'.tif') : 0;
  $ret = $self->social_pixels(write=>$out[3]);
  if ($ret->status == 0) {
    print $ret->message;
    die;
  } else {
    print $ret->message if $args{verbose};
  };
  undef $ret;

  ## construct an animated gif of the mask building process
  if ($args{animate}) {

  };
};

sub import_elastic_image {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;

  my $ret = Xray::BLA::Return->new;
  my $p = Image::Magick->new();
  $p->Read(filename=>$self->elastic_file);
  $self->elastic_image($p);

  if ($self->elastic_image->Get('version') !~ m{Q32}) {
    $ret->message("The version of Image Magick on your computer does not support 32-bit depth.");
    $ret->status(0);
    return $ret;
  };

  $self->columns($self->elastic_image->Get('columns'));
  $self->rows($self->elastic_image->Get('rows'));
  my $str = "Processing ".$self->elastic_file."\n";
  $str   .= sprintf "\t%d columns, %d rows, %d total pixels\n",
    $self->columns, $self->rows, $self->columns*$self->rows;
  if ($args{write}) {
    $self->elastic_image->Write($args{write});
    $str .= "\tSaved initial image to ".$args{write}."\n";
  };
  $ret->message($str);
  return $ret;
};

sub bad_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;
  my $ret = Xray::BLA::Return->new;

  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $self->rows-1) {
      my $str = $self->elastic_image->Get("pixel[$co,$ro]");
      my @pix = split(/,/, $str);
      #    print "$co, $ro: $pix[0]\n" if $pix[0]>5;
      if ($pix[0] > $self->bad_pixel_value) {
	$self->push_bad_pixel_list([$co,$ro]);
  	$self->elastic_image->Set("pixel[$co,$ro]"=>0);
  	++$removed;
  	++$off;
      } elsif ($pix[0] < $self->weak_pixel_value) {
  	$self->elastic_image->Set("pixel[$co,$ro]"=>0);
  	++$toosmall;
  	++$off;
      } else {
  	if ($pix[0]) {++$on} else {++$off};
      };
    };
  };

  my $str = "First pass\n";
  $str   .= "\tRemoved $removed bad pixels and $toosmall weak pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  if ($args{write}) {
    $self->elastic_image->Write($args{write});
    $str .= "\tSaved first pass image to ".$args{write}."\n";
  };
  $ret->message($str);
  return $ret;
};

sub lonely_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;
  my $ret = Xray::BLA::Return->new;

  my ($removed, $on, $off) = (0,0,0);
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $self->rows-1) {

      my @pix = split(/,/, $self->elastic_image->Get("pixel[$co,$ro]"));

      ++$off, next if ($pix[0] == 0);

      my $count = 0;
      foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc == -1));
	next if (($co == $self->columns-1) and ($cc == 1));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr == -1));
	  next if (($ro == $self->rows-1) and ($rr == 1));

	  my $arg = sprintf("pixel[%d,%d]", $co+$cc, $ro+$rr);
	  my @neighbor = split(/,/, $self->elastic_image->Get($arg));

	  ++$count if ($neighbor[0] > 0);
	};
      };
      if ($count < $self->lonely_pixel_value) {
	$self->elastic_image->Set("pixel[$co,$ro]"=>0);
	++$removed;
	++$off;
      } else {
	++$on;
      };
    };
  };


  my $str = "Second pass\n";
  $str   .= "\tRemoved $removed lonely pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  if ($args{write}) {
    $self->elastic_image->Write($args{write});
    $str .= "\tSaved second pass image to ".$args{write}."\n";
  };
  $ret->message($str);
  return $ret;
};

sub social_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  my $ret = Xray::BLA::Return->new;

  my ($added, $on, $off) = (0,0,0);
  my @addlist = ();
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $self->rows-1) {

      my @pix = split(/,/, $self->elastic_image->Get("pixel[$co,$ro]"));

      ++$on, next if ($pix[0] > 0);

      my $count = 0;
      foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc == -1));
	next if (($co == $self->columns-1) and ($cc == 1));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr == -1));
	  next if (($ro == $self->rows-1) and ($rr == 1));

	  my $arg = sprintf("pixel[%d,%d]", $co+$cc, $ro+$rr);
	  my @neighbor = split(/,/, $self->elastic_image->Get($arg));

	  ++$count if ($neighbor[0] > 0);
	};
      };
      if ($count > $self->social_pixel_value) {
	push @addlist, [$co, $ro];
	++$added;
	++$on;
      } else {
	++$off;
      };
    };
  };
  foreach my $px (@addlist) {
    my $arg = sprintf("pixel[%d,%d]", $px->[0], $px->[1]);
    $self->elastic_image->Set($arg=>'5,5,5,0');
  };

  my $str = "Third pass\n";
  $str   .= "\tAdded $added social pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  if ($args{write}) {
    $self->elastic_image->Write($args{write});
    $str .= "\tSaved third pass image to ".$args{write}."\n";
  };
  $ret->message($str);
  return $ret;
};

# # HERFD scan on Au3MarineCyanos1
# # ----------------------------------
# # energy time ring_current i0 it ifl ir roi1 roi2 roi3 roi4 tif
#     11850.000   20  95.3544291727  1400844   830935   653600   956465      38      18      15      46      1

sub scan {
  my ($self) = @_;
  my $ret = Xray::BLA::Return->new;

  my $scanfile = File::Spec->catfile($self->scanfolder, $self->stub.'.001');
  print "Reading scan from $scanfile\n";;
  open(my $SCAN, "<", $scanfile);
  my $fname = join("_", $self->stub, $self->peak_energy).'.001';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);
  open(my $OUT, ">", $outfile);
  print $OUT "# HERFD scan on " . $self->stub . "\n";
  print $OUT "# ---------------------------------\n ";
  print $OUT "# energy time ring_current i0 it ifl ir herfd\n";
  #my $count = 0;
  while (<$SCAN>) {
    next if m{\A\#};
    next if m{\A\s*\z};
    chomp;
    my @list = split(" ", $_);
    printf $OUT "  %12.3f  %3d  %s  %7d  %7d  %7d  %7d", @list[0..6];
    #if (! ++$count % 2) {
    #  local $|=1;
    #  print STDOUT '.';
    #};
    my $ret = $self->apply_mask($list[11]);
    printf $OUT "  %d\n", $ret->status;
  };
  #print STDOUT "\n";
  close $SCAN;
  close $OUT;
  print "Wrote $outfile\n";
  return $ret;
};


sub apply_mask {
  my ($self, $tif) = @_;
  my $ret = Xray::BLA::Return->new;

  my $fname = sprintf("%s_%5.5d.tif", $self->stub, $tif);
  my $image = File::Spec->catfile($self->tiffolder, $fname);
  printf "  %3d, %s\n", $tif, $image;

  my $datapoint = Image::Magick->new();
  $datapoint -> Read($image);
  my $sum = 0;
  foreach my $c (0 .. $self->columns-1) {
    foreach my $r (0 .. $self->rows-1) {
      my $str  = $self->elastic_image->Get("pixel[$c,$r]");
      my @mask = split(/,/, $str);
      next if not $mask[0];
      $str     = $datapoint->Get("pixel[$c,$r]");
      my @data = split(/,/, $str);
      $sum += $data[0];
    };
  };
  $ret->status($sum);
  return $ret;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Xray::BLA - Convert bent-Laue analyzer + areal detector data in XANES spectra

=head1 VERSION

0.1

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 ATTRIBUTES

=over 4

=item C<stub>

=item C<scanfile>

=item C<scanfolder>

=item C<tiffolder>

=item C<peak_energy>

This normally takes the tabulated value of the measured fluorescence
line.  For example, for the the gold L3 edge experiment, the L alpha 1
line is likely used.  It's tabulated value is 9715 eV.

The image containing the data measured from the elastic scattering
with the incident energy at this energy will have a filename something
like F<E<lt>stubE<gt>_elsatic_E<lt>energyE<gt>_00001.tif>.

This value can be changed to some other measured elastic energy in
order to scan the off-axis portion of the spectrum.

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

Inthe third pass over the elastic image, dark pixels which are
surrounded by larger than this number of illuminated pixels are
presumed to be a part of the image of the peak energy.  They are given
a value of 5 counts.  This serves the prupose of making the elastic
image a solid mask with few gaps in the image of the main peak.

=item C<elastic_file>

This contains the name of the elastic image file.  It is constructed
from the values of C<stub>, C<peak_energy>, and C<tiffolder>.

=item C<elastic_image>

This contains the L<Image::Magick> object corresponding to the elastic
image.

=item C<elastic_mask>

This contains the L<Image::Magick> object corresponding to the mask
constructed from the elastic image.

=item C<columns>

When the elastic file is read, this gets set with the number of
columns in the image.  All images in the measurement are presumed to
have the same number of columns.

=item C<rows>

When the elastic file is read, this gets set with the number of rows
in the image.  All images in the measurement are presumed to have the
same number of rows.

=back

=head1 METHODS

=head2 Calibration methods

=over 4

=item C<import_elastic_image>

Import the file containing the elastic image and perform the first
pass in which bad pixels and weak pixels are removed from the image.

  $spectrum -> import_elastic_image;

The intermediate image can be saved:

  $spectrum -> import_elastic_image(write => "firstpass.tif");

=item C<lonely_pixels>

Make the second pass over the elastic image.  Remove illuminated
pixels which are not surrounded by enough other illuminated pixels.

  $spectrum -> lonely_pixels;

The intermediate image can be saved:

  $spectrum -> lonely_pixels(write => "secondpass.tif");

=item C<social_pixels>

Make the third pass over the elastic image.  Include dark pixels which
are surrounded by enough illuminated pixels.

=back

=head2 Data processing methods

=over 4

=item C<lonely_pixels>

=back


=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter> for a description of the configuration system.

=head1 DEPENDENCIES

=over 4

=item *

L<Moose>

=item *

L<Image::Magick>

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

      sudo ln -s /usr/lib/libperl.5.10.1.so /usr/lib/libperl

Adjust the version number on the perl library as needed.


=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
