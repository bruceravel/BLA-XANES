package Xray::BLA;
use Xray::BLA::Return;

use version;
our $VERSION = version->new('0.1');

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;

use Image::Magick;

with 'MooseX::SetGet';		# this is mine....

has 'stub'       => (is => 'rw', isa => 'Str',     default => q{});
has 'scanfile'   => (is => 'rw', isa => 'Str',     default => q{});
has 'scanfolder' => (is => 'rw', isa => 'Str',     default => q{});
has 'tiffolder'  => (is => 'rw', isa => 'Str',     default => q{});

has 'peak_energy' => (is => 'rw', isa => 'Int',   default => 0);

has 'bad_pixel_value'  => (is => 'rw', isa => 'Int',   default => 500);
has 'weak_pixel_value' => (is => 'rw', isa => 'Int',   default => 3);

has 'lonely_pixel_value' => (is => 'rw', isa => 'Int',   default => 3);
has 'social_pixel_value' => (is => 'rw', isa => 'Int',   default => 2);

has 'elastic_file'  => (is => 'rw', isa => 'Str',   default => q{});
has 'elastic_image' => (is => 'rw', isa => 'Image::Magick');
has 'elastic_mask'  => (is => 'rw', isa => 'Image::Magick');

has 'columns'  => (is => 'rw', isa => 'Int',   default => 0);
has 'rows'     => (is => 'rw', isa => 'Int',   default => 0);


sub import_elastic_image {
  my ($self) = @_;

  my $ret = Xray::BLA::Return->new;
  my $p = Image::Magick->new();
  $p->Read(filename=>$self->elastic_file);
  $self->elastic_image($p);

  if ($self->elastic_image->Get('version') !~ m{Q32}) {
    $ret->message("Your Image Magick does not support 32-bit depth.");
    $ret->status(0);
    return $ret;
  };

  $self->columns($self->elastic_image->Get('columns'));
  $self->rows($self->elastic_image->Get('rows'));


  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $self->rows-1) {
      my $str = $self->elastic_image->Get("pixel[$co,$ro]");
      my @pix = split(/,/, $str);
      #    print "$co, $ro: $pix[0]\n" if $pix[0]>5;
      if ($pix[0] > $self->bad_pixel_value) {
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

  my $str = "Initial processing of ".$self->elastic_file."\n";
  $str   .= "\tRemoved $removed bad pixels and $toosmall weak pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $ret->message($str);
  return $ret;
};



__PACKAGE__->meta->make_immutable;
1;
