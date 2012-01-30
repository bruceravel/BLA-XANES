#!/usr/bin/perl

use Test::More tests => 6;
use File::Basename;
use File::Spec;

my $here  = dirname($0);

use Xray::BLA;
my $bla = Xray::BLA -> new(backend=>'Imager', stub=>'example', energy=>'9713',
			   scanfolder=>$here, tiffolder=>$here);

SKIP: {
    skip 'Imager not available', 6 if not eval "require Imager";

    my $ret = $bla->check;
    ok($ret->status == 1, 'can read scan and elastic files');
    ok($bla->get_version >= 0.87, 'Correct version of Imager is available');
    my $ei = $bla->elastic_image;

    ok((($bla->get_columns($ei) == 487) and ($bla->get_rows($ei) == 195)), 'width and height');



    my ($r, $g, $b, $a) = $bla->get_pixel($ei, 86,  150);
    ok($r == 10, 'good pixel');
    ($r, $g, $b, $a) = $bla->get_pixel($ei, 427,  32);
    ok($r == 0, 'zero pixel');
    ($r, $g, $b, $a) = $bla->get_pixel($ei, 259, 91);
    ok($r == 1048575, 'bad pixel');
  };
