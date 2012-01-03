#!/usr/bin/perl -I/home/bruce/git/XAS-Data-Interchange/perl/lib
use Test::More tests => 3;

use Image::Magick;

my $im = Image::Magick -> new();
ok($im->Get('version') =~ m{Q32}, 'Image Magick supports signed 32 bit integers');

eval 'require Xray::BLA;';
ok((not $@), 'Xray::BLA imports correctly.');

my $spectrum = Xray::BLA->new;
ok( defined($spectrum) && blessed $spectrum eq 'Xray::BLA',     'new() works' );
