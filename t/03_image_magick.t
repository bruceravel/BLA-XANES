#!/usr/bin/perl
use Test::More tests => 5;
use File::Basename;
use File::Spec;

my $here  = dirname($0);

use Xray::BLA;

SKIP: {
    skip 'Image::Magick not available', 5 if not eval "require Image::Magick";

    my $bla = Xray::BLA -> new(backend=>'ImageMagick', stub=>'example', energy=>'9713',
			       scanfolder=>$here, tiffolder=>$here);
    $bla->check;
    my $ret = $bla->check;
    ok($ret->status == 1, 'can read scan and elastic files ');

  SKIP: {
      skip 'Image::Magick not capable of reading 32 bit images', 4 if $bla->get_version !~ m{Q32};

      my $ei = $bla->elastic_image;

      ok((($bla->get_columns($ei) == 487) and ($bla->get_rows($ei) == 195)), 'width and height');

      my ($r, $g, $b, $a) = $bla->get_pixel($ei, 86,  150);
      ok($r == 10, 'good pixel');
      ($r, $g, $b, $a) = $bla->get_pixel($ei, 427,  32);
      ok($r == 0, 'zero pixel');
      ($r, $g, $b, $a) = $bla->get_pixel($ei, 259, 91);
      ok($r == 1048575, 'bad pixel');

    };
  };
