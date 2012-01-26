package Xray::BLA::Backend::Imager;

use Moose::Role;
use Imager;
use Math::Round qw(round);

has 'elastic_image' => (is => 'rw', isa => 'Imager');
has 'backend'	    => (is => 'rw', isa => 'Str', default => 'Imager');

sub read_image {
  my ($self, $file) = @_;
  my $p = Imager->new(file=>$file);
  return $p;
};

sub write_image {
  my ($self, $image, $file) = @_;
  $image->write(file=>$file);
  return $image;
};

sub animate {
  my ($self, @files) = @_;
  warn "not yet animating with Imager";
  # my $im = Image::Magick->new;
  # $im -> Read(@files);
  # foreach my $i (0 .. $#files) {
  #   foreach my $pix (@{$self->bad_pixel_list}) {
  #     my $co = $pix->[0];
  #     my $ro = $pix->[1];
  #     $self->set_pixel($im->[$i], $co, $ro, 0);
  #   };
  # };
  my $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->peak_energy, "mask_anim").'.tif');
  # my $x = $im -> Write($fname);
  # warn $x if $x;
  return $fname;
};

sub get_pixel {
  my ($self, $image, $x, $y) = @_;
  my @rgba = $image->getpixel(x=>$x, y=>$y, type=>'float')->rgba;
  return round($rgba[0]*2**32);
};


## this is scary.  not scaling $value back down by the same amount as it was scaled up in get_pixel!
sub set_pixel {
  my ($self, $image, $x, $y, $value) = @_;
  #$image->setpixel(x=>$x, y=>$y, color=>[$value/(2**32),0,0,0]);
  $image->setpixel(x=>$x, y=>$y, color=>[$value,0,0,0]);
};

sub get_columns {
  my ($self, $image) = @_;
  return $image->getwidth;
};
sub get_rows {
  my ($self, $image) = @_;
  return $image->getheight;
};
sub get_version {
  my ($self, $image) = @_;
  return $Imager::VERSION;
};


1;
