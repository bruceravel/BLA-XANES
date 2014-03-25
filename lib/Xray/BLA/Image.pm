package Xray::BLA::Image;

use Moose;
use PDL::Lite;
use PDL::Graphics::Simple;
use PDL::Graphics::Gnuplot;
use PDL::IO::FlexRaw;
use PDL::NiceSlice;

has 'parent' => (is => 'rw', isa => 'Xray::BLA');
has 'image' =>  (is => 'rw', isa => 'PDL', default => sub {PDL::null});

use Const::Fast;
##const my $BIT_DEPTH   => 2**32;
const my $IMAGE_WIDTH => 487;

## A million thanks to Chris Marshall for his help on the problem
## of reading signed 32 bit tiff files!
## see http://mailman.jach.hawaii.edu/pipermail/perldl/2014-March/008623.html
sub Read {
  my ($self, $file) = @_;
  my $bytes =  -s $file;
  my $longs = $bytes / 4;

  my $img  = readflex($file, [ { Type=>'long', NDims=>1, Dims=>[$longs] } ]);
  my $im2d = $img(1024:-1)->splitdim(0,$IMAGE_WIDTH);
  $im2d->badflag(1);
  #$im2d->inplace->setvaltobad(0);
  $self->image($im2d);
  my ($c, $r) = $im2d->dims;
  $self->parent->columns($c);
  $self->parent->rows($r);
  return $im2d;
};

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
#   $self->image_width($width);
#   $self->image_height($height);
#   return $self;
# };



__PACKAGE__->meta->make_immutable;
1;
