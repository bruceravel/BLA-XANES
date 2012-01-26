package Xray::BLA::Backend::ImageMagick;

use Moose::Role;
use Image::Magick;

has 'elastic_image' => (is => 'rw', isa => 'Image::Magick');
has 'backend'	    => (is => 'rw', isa => 'Str', default => 'Image::Magick');

sub read_image {
  my ($self, $file) = @_;
  my $p = Image::Magick->new();
  my $x = $p->Read($file);
  return $p;
};

sub write_image {
  my ($self, $image, $file) = @_;
  $image->Write($file);
  return $image;
};

sub animate {
  my ($self, @files) = @_;
  my $im = Image::Magick->new;
  $im -> Read(@files);
  foreach my $i (0 .. $#files) {
    foreach my $pix (@{$self->bad_pixel_list}) {
      my $co = $pix->[0];
      my $ro = $pix->[1];
      $self->set_pixel($im->[$i], $co, $ro, 0);
    };
  };
  my $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_anim").'.tif');
  my $x = $im -> Write($fname);
  warn $x if $x;
  return $fname;
};

sub get_pixel {
  my ($self, $image, $x, $y) = @_;
  my @rgb = split(/,/, $image->Get("pixel[$x,$y]"));
  return $rgb[0];
};

sub set_pixel {
  my ($self, $image, $x, $y, $value) = @_;
  $image->Set("pixel[$x,$y]"=>"$value,$value,$value,0");
};

sub get_columns {
  my ($self, $image) = @_;
  return $image->Get('columns');
};
sub get_rows {
  my ($self, $image) = @_;
  return $image->Get('rows');
};
sub get_version {
  my ($self, $image) = @_;
  return $image->Get('version');
};

1;

