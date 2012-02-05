package Xray::BLA::Backend::ImageMagick;

use Moose::Role;
use MooseX::Aliases;
use Image::Magick;

has 'elastic_image' => (is => 'rw', isa => 'Image::Magick');

sub new_image {
  my ($self) = @_;
  my $p = Image::Magick->new();
  return $p;
};

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
  my $fname = $self->mask_file("anim", 'tif');
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
alias get_width => 'get_columns';
sub get_rows {
  my ($self, $image) = @_;
  return $image->Get('rows');
};
alias get_height => 'get_rows';
sub get_version {
  my ($self) = @_;
  my $im = Image::Magick->new();
  my $str = $im->Get('version');
  undef $im;
  return $str;
};

1;




=head1 NAME

Xray::BLA::Backends::ImageMagick - Use Image::Magick as the BLA imagine handling backend

=head1 VERSION

0.2

=head1 DESCRIPTION

This provides a role for L<Xray::BLA> for handling 32 bit tiff images
using L<Image::Magick>.  Some of these methods may behave oddly for
any other kind of image, including other kinds of tiff images.  These
methods are intended to work with the signed 32 bit integer tiff from
the Pilatus.

=head1 METHODS

=over 4

=item C<read_image>

Open an image as an Image::Magick object

=item C<write_image>

Export an Image::Magick object to a file.

=item C<animate>

Create an animation demonstrating the steps of mask creation

=item C<get_pixel>

Get the value associated with a pixel.

  $val = $bla->get_pixel($image, $x, $y);

=item C<set_pixel>

Set the value associated with a pixel.

  $val = $bla->set_pixel($image, $x, $y, 5);

=item C<get_columns>, C<get_width>

Get the width of an image.

  $width = $bla->get_columns($image);

=item C<get_rows>, C<get_height>

Get the height of an image.

  $number_of_rows = $bla->get_height($image);

=item C<get_version>

Get versioning information for Image::Magick.

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to write get_row method

=item *

Write animate as a gif

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
