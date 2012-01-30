package Xray::BLA::Backend::Imager;

use Moose::Role;
use MooseX::Aliases;
use Imager;
use Math::Round qw(round);

has 'elastic_image' => (is => 'rw', isa => 'Imager');

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
  my @images = map {Imager->new(file=>$_)} @files;
  my $fname = $self->mask_file("anim", 'tif');
  Imager->write_multi({ file=>$fname, type=>'tiff' }, @images)
    or die Imager->errstr;
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
  $image->setpixel(x=>$x, y=>$y, color=>[$value,0,0]);
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


1;



=head1 NAME

Xray::BLA::Backends::Imager - Use Imager as the BLA imagine handling backend

=head1 VERSION

0.2

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

I don't quite understand how the 32 bit numbers are handled when get
and set.  Using the image from the t/ directory:

    my ($r, $g, $b, $a) = $bla->get_pixel($ei, 86,  150);
    print $r, $/;
        ==> 10
    $bla->set_pixel($ei, 86,  150, 1);
    ($r, $g, $b, $a) = $bla->get_pixel($ei, 86,  150);
    print join("|", $r, round($r/2**24)), $/;
        ==> 16843009|1

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
