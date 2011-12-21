#!/usr/bin/perl -I/home/bruce/git/BLA-XANES/lib

use strict;
use warnings;
use Xray::BLA;
use File::Spec;

my $spectrum = Xray::BLA->new;

my $datalocation = '/home/bruce/Data/NIST/10ID/2011.12/';
$spectrum->set(scanfolder  => File::Spec->catfile($datalocation, "scans"),
	       tiffolder   => File::Spec->catfile($datalocation, "tiffs"),
	       outfolder   => File::Spec->catfile($datalocation, "processed"),
	       stub        => "Au3PlectonemaT8",
	       peak_energy => 9713,
	       weak_pixel_value => 2,
	       social_pixel_value => 1,
	      );

#my @elastic = (9703, 9705, 9707, 9709, 9711, 9713, 9715, 9717, 9719);
#foreach my $e (@elastic) {
#my $e = 9713;
#$spectrum -> peak_energy($e);

foreach my $t (qw(0 2 4 6 8 14 20)) {
  my $stub = sprintf("Au3PlectonemaT%s", $t);
  $spectrum -> stub($stub);
  $spectrum -> mask(save=>0, verbose=>1, animate=>1);
  $spectrum -> scan(verbose=>1);
};
