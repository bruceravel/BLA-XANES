package Xray::BLA;
use Xray::BLA::Return;

use version;
our $VERSION = version->new('0.2');

use Moose;
#with 'Xray::BLA::Backend::ImageMagick';
with 'Xray::BLA::Backend::Imager';
no warnings qw(redefine);

use File::Spec;

use vars qw($XDI_exists);
$XDI_exists = eval "require Xray::XDI" || 0;


my $stub = 0;
if ( (($^O eq 'MSWin32') or ($^O eq 'cygwin')) and ($ENV{TERM} eq 'dumb')) {
  my $WCA_exists = (eval "require Win32::Console::ANSI");
  if ($WCA_exists) {
    import Term::ANSIColor qw(:constants);
    # sub BOLD    {color('bold')};
    # sub WHITE   {color('white')};
    # sub YELLOW  {color('yellow')};
    # sub RED     {color('red')};
    # sub GREEN   {color('green')};
    # sub CYAN    {color('cyan')};
    # sub RESET   {color('reset')};
  } else {
    $stub = 1
  };
} else {
  my $ANSIColor_exists = (eval "require Term::ANSIColor");
  if ($ANSIColor_exists) {
    import Term::ANSIColor qw(:constants);
  } else {
    $stub = 1;
  };
};
$stub = 1 if ($ENV{TERM} eq 'dumb');
#$stub = 1 if $nocolor;
if ($stub) {
  sub BOLD    {q{}};
  sub WHITE   {q{}};
  sub YELLOW  {q{}};
  sub RED     {q{}};
  sub GREEN   {q{}};
  sub CYAN    {q{}};
  sub RESET   {q{}};
};


##with 'MooseX::MutatorAttributes';
##with 'MooseX::SetGet';		# this is mine....

has 'stub'		 => (is => 'rw', isa => 'Str', default => q{});
has 'scanfile'		 => (is => 'rw', isa => 'Str', default => q{});
has 'scanfolder'	 => (is => 'rw', isa => 'Str', default => q{});
has 'tiffolder'		 => (is => 'rw', isa => 'Str', default => q{});
has 'outfolder'		 => (is => 'rw', isa => 'Str', default => q{});

has 'peak_energy'	 => (is => 'rw', isa => 'Int', default => 0);
has 'columns'            => (is => 'rw', isa => 'Int', default => 0);
has 'rows'               => (is => 'rw', isa => 'Int', default => 0);

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


sub mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{save}    || 0;
  $args{verbose} || 0;
  $args{animate} || 0;
  $args{write}    = 0;
  $args{write}    = 1 if ($args{animate} or $args{save});


  $self->clear_bad_pixel_list;
  $self->clear_mask_pixel_list;
  my $elastic = join("_", $self->stub, 'elastic', $self->peak_energy).'_00001.tif';
  $self->elastic_file(File::Spec->catfile($self->tiffolder, $elastic));

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
  ##print $#{$self->mask_pixel_list}, $/;

  ## construct an animated gif of the mask building process
  if ($args{animate}) {
    my $fname = $self->animate(@out);
    print $self->assert("Wrote $fname", YELLOW), "\n" if $args{verbose};
  };
  if ($args{save}) {
    my $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_N").'.tif');
    print $self->assert("Saved stages of mask creation to $fname", YELLOW), "\n" if $args{verbose};
  } else {
    unlink $_ foreach @out;
  };
};

sub import_elastic_image {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} || 0;

  my $ret = Xray::BLA::Return->new;
  $self->elastic_image($self->read_image($self->elastic_file));

  if (($self->backend eq 'Image::Magick') and ($self->get_version($self->elastic_image) !~ m{Q32})) {
    $ret->message("The version of Image Magick on your computer does not support 32-bit depth.");
    $ret->status(0);
    return $ret;
  };
  if (($self->backend eq 'Imager') and ($self->get_version($self->elastic_image) < 0.87)) {
    $ret->message("This program requires Imager version 0.87 or later.");
    $ret->status(0);
    return $ret;
  };

  $self->columns($self->get_columns($self->elastic_image));
  $self->rows($self->get_rows($self->elastic_image));
  my $str = $self->assert("\nProcessing ".$self->elastic_file, YELLOW);
  $str   .= sprintf "\tusing the %s backend\n", $self->backend;
  $str   .= sprintf "\t%d columns, %d rows, %d total pixels\n",
    $self->columns, $self->rows, $self->columns*$self->rows;
  if ($args{write}) {
    $self->write_image($self->elastic_image, $args{write});
    # $self->elastic_image->Write($args{write});
  };
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
      #my @pix = split(/,/, $str);
      #    print "$co, $ro: $pix[0]\n" if $pix[0]>5;
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

  my $str = $self->assert("First pass", CYAN);
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

  my ($removed, $on, $off) = (0,0,0);
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


  my $str = $self->assert("Second pass", CYAN);
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

  my ($added, $on, $off, $count) = (0,0,0,0);
  my @addlist = ();
  my ($arg, $val) = (q{}, q{});
  foreach my $co (0 .. $ncols) {
    foreach my $ro (0 .. $nrows) {

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

  my $str = $self->assert("Third pass", CYAN);
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

  my (@data, @point);

  my $scanfile = File::Spec->catfile($self->scanfolder, $self->stub.'.001');
  print $self->assert("Reading scan from $scanfile", YELLOW);
  open(my $SCAN, "<", $scanfile);
  my $fname = join("_", $self->stub, $self->peak_energy);
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

  print $self->assert("Wrote $outfile", BOLD.GREEN);
  return $ret;
};


sub apply_mask {
  my ($self, $tif, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  my $ret = Xray::BLA::Return->new;

  my $fname = sprintf("%s_%5.5d.tif", $self->stub, $tif);
  my $image = File::Spec->catfile($self->tiffolder, $fname);
  printf("  %3d, %s", $tif, $image) if ($args{verbose} and (not $tif % 10));

  my $datapoint = $self->read_image($image);
  my $sum = 0;

  foreach my $pix (@{$self->mask_pixel_list}) {
    $sum += $self->get_pixel($datapoint, $pix->[0], $pix->[1]);
  };

  ## this is a much slower way to apply the mask:
  # foreach my $c (0 .. $self->columns-1) {
  #   foreach my $r (0 .. $self->rows-1) {
  #     my @mask = split(/,/, $self->elastic_image->Get("pixel[$c,$r]"));
  #     next if not $mask[0];
  #     my @data = split(/,/, $datapoint->Get("pixel[$c,$r]"));
  #     $sum += $data[0];
  #   };
  # };
  printf("  %7d\n", $sum) if ($args{verbose} and (not $tif % 10));
  $ret->status($sum);
  return $ret;
};


sub assert {
  my ($self, $message, $color) = @_;
  return $color . $message . RESET . $/;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Xray::BLA - Convert bent-Laue analyzer + Pilatus 100K data to a XANES spectrum

=head1 VERSION

0.1

=head1 SYNOPSIS

   my $spectrum = Xray::BLA->new;

   my $datalocation = '/home/bruce/Data/NIST/10ID/2011.12/';
   $spectrum->scanfolder('/path/to/scanfolder');
   $spectrum->tiffolder('/path/to/tiffolder');
   $spectrum->outfolder('/path/to/outfolder');
   $spectrum->stub('myscan');
   $spectrum->peak_energy(9713);

   $spectrum->mask(write=>0, verbose=>1, animate=>0);
   $spectrum->scan(verbose=>1);

=head1 DESCRIPTION



=head1 ATTRIBUTES

=over 4

=item C<stub>

The basename of the scan and image files.  The scan file is called
C<E<lt>stubE<gt>.001>, the image files are called
C<E<lt>stubE<gt>_NNNNN.tif>, and the processed column data files are
called C<E<lt>stubE<gt>_E<lt>peak_energyE<gt>.001>.

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

In the third pass over the elastic image, dark pixels which are
surrounded by larger than this number of illuminated pixels are
presumed to be a part of the image of the peak energy.  They are given
a value of 5 counts.  This serves the prupose of making the elastic
image a solid mask with few gaps in the image of the main peak.

=item C<elastic_file>

This contains the name of the elastic image file.  It is constructed
from the values of C<stub>, C<peak_energy>, and C<tiffolder>.

=item C<elastic_image>

This contains the backend object corresponding to the elastic image.

=item C<npixels>

The number of illuminated pixels in the mask.  That is, the number of
pixels contrributing to the HERFD signal.

=item C<columns>

When the elastic file is read, this is set with the number of columns
in the image.  All images in the measurement are presumed to have the
same number of columns.

=item C<rows>

When the elastic file is read, this is set with the number of rows in
the image.  All images in the measurement are presumed to have the
same number of rows.

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
C<peak_energy>.

  $spectrum->mask(save=>0, verbose=>0, animate=>0);

When true, the C<verbose> argument causes messages to be printed to
standard output with information about each stage of mask creation.

When true, the C<save> argument causes a tif file to be saved at
each stage of processing the mask.

When true, the C<animate> argument causes a properly scaled animation
to be written showing the stages of mask creation.  Currently, this is
a signed 32 bit tiff animation, so only ImageJ or the specially
modified Image Magick can open it.  Sigh....

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

=over 4

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

L<MooseX::MutatorAttributes>

=item *

L<Imager> or L<Image::Magick> or, possibly, L<Graphics::Magick>

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

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Set backend by attribute from the calling script

=item *

Write tests that use an actual tif image

=item *

write tests for both backends (using skip as needed)

=item *

Make sure this POD makes sense describing both backends

=item *

Write PODs for the backends

=item *

write images and animations with Imager (gif?)

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
