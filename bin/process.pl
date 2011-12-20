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
	       #stub        => "Au3Cltest4",
	       #stub        => "Au3MarineCyanos1",
	       stub        => "Au3OH31",
	       peak_energy => 9713,
	      );


foreach my $e (9703, 9705, 9707, 9709, 9711, 9713, 9715, 9717, 9719) {
  $spectrum -> peak_energy($e);
  my $elastic = join("_", $spectrum->stub, 'elastic', $spectrum->peak_energy).'_00001.tif';
  $spectrum->elastic_file(File::Spec->catfile($spectrum->tiffolder, $elastic));

  $spectrum->mask(write=>0, verbose=>1);
  $spectrum->scan();
};

