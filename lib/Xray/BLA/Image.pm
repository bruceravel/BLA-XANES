package Xray::BLA::Image;

use Image::Info qw(image_info);
use Moose::Role;
use PDL::Lite;
use PDL::IO::FlexRaw;
use PDL::NiceSlice;

use Const::Fast;
const my $IMAGE_WIDTH => 487;

# has 'pilatus_metadata' => (
# 			   traits    => ['Hash'],
# 			   is        => 'rw',
# 			   isa       => 'HashRef',
# 			   default   => sub { {} },
# 			   documentation => "A hash reference containing metadata from the tif image produced by the Pilatus."
# 			  );


## A million thanks to Chris Marshall for his help on the problem
## of reading signed 32 bit tiff files!
## see http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008623.html
##
## The server at U Hawaii no longer exists.  Here is the exchange as
## preserved on the Internet Archive Wayback Machine at
## https://web.archive.org/web/20141030084128/http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008623.html
## (accessed 16 Dec 2016)

# [Perldl] signed 32-bit tiff files
#
# Chris Marshall devel.chm.01 at gmail.com
# Sun Mar 23 09:39:26 HST 2014
#
#     Previous message: [Perldl] signed 32-bit tiff files
#     Next message: [Perldl] signed 32-bit tiff files
#     Messages sorted by: [ date ] [ thread ] [ subject ] [ author ]
#
# Hi Bruce-
#
# I'm not sure how to fix the TIFF IO issue but looking at your
# sensor docs there is a raw image file format that could be
# used.  I also saw a note that the data in the TIFF file is
# uncompressed following a 4096 byte header so it is possible
# to us PDL::IO::FlexRaw to read the data files.  (I don't know
# the best way to determine the image size and sensor info
# which, presumably, is in the header of the .tif file).
#
# I used the ImageMagic identify command to determine the
# dimensions of the image then the follow session in pdl shows
# using PDL::IO::FlexRaw to read the data.  I've attached the
# log of the image data image to prove that the file was loaded
# correctly.  Note the use of badvalues to avoid log(0) problems.
#
# Hope this helps,
# Chris
#
# pdl> $bytes =  -s 'example-s32.tif';
#
# pdl> $longs = $bytes / 4;
#
# pdl> $img = readflex('example-s32.tif', [ { Type=>'long', NDims=>1,
# Dims=>[$longs] } ]);
#
# pdl> $im2d = $img(1024:-1)->splitdim(0,487);
#
# pdl> $im2d->badflag(1);
#
# pdl> $im2d->inplace->setvaltobad(0);
#
# pdl> imag2d $im2d->log/$im2d->log->max;
# glutCloseFunc: not implemented
# Type Q or q to stop twiddling...
# Stop twiddling command, key 'q', detected.
# Stopped twiddle-ing!
#
# pdl> ?vars
# PDL variables in package main::
#
# Name         Type   Dimension       Flow  State          Mem
# ----------------------------------------------------------------
# $im2d          Long D [487,195]            PB           0.36MB
# $img           Long D [95989]              P            0.37MB
#
# pdl> wpic($im2d->log->setbadtoval(0)/$im2d->log->max, 'log-example-s32.tif')
#
#
#
# On Thu, Mar 20, 2014 at 7:14 PM, Bruce Ravel <bravel at bnl.gov> wrote:
# >
# > Hi,
# >
# > This gizmo -- https://www.dectris.com/pilatus_overview.html -- is a
# > wonderful X-ray detector with an awkward feature.  It saves its images
# > as signed 32 bit tiff files, which is a valid, if unusual, form of a
# > tiff file.
# >
# > Here is an example of an image from this detector:
# > https://github.com/bruceravel/BLA-XANES/blob/master/share/example-s32.tif
# >
# > It seems as though this does not get imported correctly:
# >
# >   pdl> $a = rim 'example-s32.tif'
# >   pdl> imag $a
# >   Use of uninitialized value $_[0] in pattern match (m//) at
# > /usr/local/share/perl/5.14.2/PDL/Graphics/Simple.pm line 854.
# >
# > Doing things like "p $a->dims" or "p $a->max" returns nothing.  So it
# > would seem that the read is silently failing.
# >
# >
# > My understanding is that PDL relies upon netpbm, which in turn relies
# > upon whatever version of libtiff it is compiled against.  So, it seems
# > that I would need to rebuild libtiff, then netpbm, then that part of
# > PDL.
# >
# > Is there something I am missing?  Is there another way of reading an
# > s32 tiff directly?
# >
# > (I am currently using https://metacpan.org/pod/Imager to preprocess
# > the tiff file.  It's a significant bottleneck.)
# >
# > Thanks!
# > Bruce

sub Read {
  my ($self, $file) = @_;
  my $bytes =  -s $file;
  my $longs = $bytes / 4;
  #print join("|", 'Read: ', caller), $/;

  my $img  = readflex($file, [ { Type=>'long', NDims=>1, Dims=>[$longs] } ]);
  $img /= $self->tifscale;
  my $im2d = $img(1024:-1)->splitdim(0,$IMAGE_WIDTH);
  $im2d->badflag(1);
  #$im2d->inplace->setvaltobad(0);
  my ($c, $r) = $im2d->dims;
  $self->columns($c);
  $self->rows($r);
  #$self->fetch_metadata;
  return $im2d->short;
};

sub fetch_metadata {
  my ($self, $file) = @_;
  my $pilatus = {};
  return $pilatus if not -e $file;
  my $info = image_info($file);
  my $text = $info->{ImageDescription};
  $text =~ s{\# }{}g;
  $text =~ s{\r}{}g;
  my @lines = split($/, $text);

  foreach my $key (qw(Model DateTime BitsPerSample width height Threshold_setting Pixel_size)) {
    next if not exists $info->{$key};
    $info->{$key} =~ s{\0}{}g;
    $pilatus->{$key} = $info->{$key};
  };

  foreach my $l (@lines) {
    if ($l =~ m{:}) {
      my @this = split(/\s*:\s*/, $l);
      $pilatus->{$this[0]} = $this[1];
    } elsif ($l =~ m{=}) {
      my @this = split(/\s*=\s*/, $l);
      $pilatus->{$this[0]} = $this[1];
    } else { 			# there are 21 poorly formatted lines
      my @this = split(/\s+(?=[0-9(])/, $l, 2);
      $pilatus->{$this[0]} = $this[1];
    };
  };
  #$self->pilatus_metadata($pilatus);
  return $pilatus;
};

## The following is from Tim Haines:
##   http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008624.html
## This will find the dimensions of the s32 tiff file (or, indeed, any
## other tiff file not readable by rpic).

# use Inline C => Config => LIBS => '-ltiff';
# use Inline C => <<'END';
#   #include <tiffio.h>
#   void tvx_img_size (const char *file) {
#     TIFF *tif=TIFFOpen(file, "r");
#     uint32 width, height;
#     TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
#     TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);
#     TIFFClose(tif);
#
#     Inline_Stack_Vars;
# Inline_Stack_Reset;
# Inline_Stack_Push(sv_2mortal(newSViv(width)));
# Inline_Stack_Push(sv_2mortal(newSViv(height)));
# Inline_Stack_Done;
#   }
# END

# sub dimensions {
#   my ($self, $file) = @_;
#   my ($width,$height) = tvx_img_size('example-s32.tif');
#   #print "width = $width\nheight = $height\n";
#   $self->columns($width);
#   $self->rows($height);
#   return $self;
# };

1;

=head1 NAME

Xray::BLA::Image - Role for importing signed 32 bit TIFF files

=head1 VERSION

See Xray::BLA

=head1 METHODS

=over 4

=item C<Read>

Read a signed 32 bit image from the Pilatus into a PDL data structure
and set the C<columns> and C<rows> attributes of the Xray::BLA object.

    my $image = $self->Read($pilatus_image);

A million thanks to Chris Marshall for his help on the problem of
reading signed 32 bit tiff files!  The old PDL-general archives from
before the move to SourceForge doen't seem to be available, Here is my
question and Chris' answer from the Wayback Machine:
L<https://web.archive.org/web/20141030084128/http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008623.html>

=item C<fetch_metadata>

Fetch metadata about the Piltus image from the tiff headers.  Return
an anonymous hash containing C<Model>, C<DateTime>, C<BitsPerSample>,
C<width>, and C<height>.

    my $hash = $self->fetch_metadata($pilatus_image);

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
