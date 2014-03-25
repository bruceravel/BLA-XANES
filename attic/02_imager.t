#!/usr/bin/perl

use Test::More tests => 11;

use File::Basename;
use File::Spec;
use List::MoreUtils qw(any);
use Math::Round qw(round);
use PDL::NiceSlice;
use Xray::BLA;

my $here  = dirname($0);


SKIP: {
  skip 'Imager not available', 11 if not eval "require Imager";

  my $bla = Xray::BLA -> new(backend=>'Imager', stub=>'example', energy=>'9713',
			     scanfolder=>$here, tiffolder=>$here);

  $bla->elastic_file(File::Spec->catfile(File::Spec->rel2abs($bla->tiffolder),
					 'example_elastic_9713_00001.tif'));
  my $img = Xray::BLA::Image->new(parent=>$bla);
  $bla->elastic_image($img->Read($bla->elastic_file));

  my @types = Imager->read_types;
  ok((any {$_ eq 'tiff'} @types), 'Imager can handle tiff files');
  ok((any {$_ eq 'gif'}  @types), 'Imager can handle gif files');


  my $ret = $bla->check;
  ok($ret->status == 1, 'can read scan and elastic files');
  ok($bla->get_version >= 0.87, 'Correct version of Imager is available');
  my $ei = $bla->elastic_image;

  ok(((($ei->dims)[0] == 487) and (($ei->dims)[1] == 195)), 'width and height');

  my $r = $ei->at( 86,  150);
  ok(round($r) == 10, 'good pixel '.$r);
  $r = $ei->at(427,  32);
  ok(round($r) == 0, 'zero pixel '.$r);
  $r = $ei->at(259, 91);
  ok(round($r) == 1048575, 'bad pixel '.$r);

  $bla -> import_elastic_image;
  $bla -> bad_pixel_value(400);
  $bla -> weak_pixel_value(2);
  $ret = $bla->bad_pixels();
  #print $ret->message;
  ok($ret->message =~ m{4 bad},      "found bad pixels");
  ok($ret->message =~ m{66819 weak}, "found weak pixels");

  $ei->( 86, 150).=5;
  $r = $ei->at( 86,  150);
  ok(round($r) == 5, 'set pixel works');
};
