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

  foreach my $key (qw(Model DateTime BitsPerSample width height)) {
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
