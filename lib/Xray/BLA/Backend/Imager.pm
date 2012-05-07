package Xray::BLA::Backend::Imager;

use Moose::Role;
use MooseX::Aliases;
use Imager;
use Imager::Color::Float;
use Math::Round qw(round);

use constant BIT_DEPTH => 2**32;

sub read_image {
  my ($self, $file) = @_;
  my $p = Imager->new(file=>$file) or die Imager->errstr();
  return $p;
};

sub get_row {
  my ($self, $image, $y) = @_;
  my @colors = $image->getscanline(y=>$y, type=>'float');
  my @y = map { my @rgba = $_->rgba; $rgba[0]*BIT_DEPTH } @colors;
  return @y;
};

sub get_columns {
  my ($self, $image) = @_;
  return $image->getwidth;
};
alias get_width => 'get_columns';
sub get_rows {
  my ($self, $image) = @_;
  return $image->getheight;
};
alias get_height => 'get_rows';
sub get_version {
  my ($self) = @_;
  return $Imager::VERSION;
};

sub animate {
  my ($self, $which, @files) = @_;
  my @images = map {Imager->new(file=>$_)} @files;
  my $fname = $self->mask_file($which, 'gif');
  Imager->write_multi({ file=>$fname, type=>'gif', gif_delay=>33, gif_loop=>0 }, @images)
    or die Imager->errstr;
  return $fname;
};

#has 'elastic_image' => (is => 'rw', isa => 'Imager');

# sub copy_image {
#   my ($self, $image) = @_;
#   my $p = $image->copy();
#   return $p;
# };

# sub write_image {
#   my ($self, $image, $file) = @_;
#   $image->write(file=>$file);
#   return $image;
# };

# sub get_pixel {
#   my ($self, $image, $x, $y) = @_;
#   my @rgba = $image->getpixel(x=>$x, y=>$y, type=>'float')->rgba;
#   return round($rgba[0]*BIT_DEPTH);
# };

# ## see http://www.molar.is/en/lists/imager-devel/2012-01/0000.shtml
# ## and http://www.molar.is/en/lists/imager-devel/2012-01/0001.shtml
# sub set_pixel {
#   my ($self, $image, $x, $y, $value) = @_;
#   $value ||= 0;
#   $image->setpixel(x=>$x, y=>$y, color=>Imager::Color::Float->new($value/BIT_DEPTH, 0, 0));
# };




1;



=head1 NAME

Xray::BLA::Backends::Imager - Use Imager as the BLA imagine handling backend

=head1 DESCRIPTION

This provides a role for L<Xray::BLA> for handling 32 bit tiff images
using L<Imager>.  Some of these methods may behave oddly for any other
kind of image, including other kinds of tiff images.  These methods
are intended to work with the signed 32 bit integer tiff from the
Pilatus.

=head1 METHODS

=over 4

=item C<read_image>

Open an image as an Imager object

=item C<write_image>

Export an Imager object to a file.

=item C<animate>

Create an animation demonstrating the steps of mask creation

=item C<get_pixel>

Get the value associated with a pixel.

  $val = $bla->get_pixel($image, $x, $y);

=item C<set_pixel>

Set the value associated with a pixel.

  $val = $bla->set_pixel($image, $x, $y, 5);

=item C<get_row>

Get the values associated with a full row of pixel.

  @vals = $bla->get_row($image, $y);

=item C<get_columns>, C<get_width>

Get the width of an image.

  $width = $bla->get_columns($image);

=item C<get_rows>, C<get_height>

Get the height of an image.

  $number_of_rows = $bla->get_height($image);

=item C<get_version>

Get versioning information for Imager.

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Write animation as a gif

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
