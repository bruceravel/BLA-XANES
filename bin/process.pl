#!/usr/bin/perl -I/home/bruce/git/BLA-XANES/lib

use strict;
use warnings;
use Xray::BLA;
use File::Spec;

my $spectrum = Xray::BLA->new;

my $datalocation = '/home/bruce/Data/NIST/10ID/2011.12/';
$spectrum->set(scanfolder  => File::Spec->catfile($datalocation, "scan"),
	       tiffolder   => File::Spec->catfile($datalocation, "tiffs"),
	       stub        => "Au3Cltest4",
	       #stub        => "Au3MarineCyanos1",
	       peak_energy => 9715,
	      );


my $elastic = join("_", $spectrum->stub, 'elastic', $spectrum->peak_energy).'_00001.tif';
$spectrum->elastic_file(File::Spec->catfile($spectrum->tiffolder, $elastic));

my $ret = $spectrum->import_elastic_image;
print $ret->message;
die if not $ret->status;
