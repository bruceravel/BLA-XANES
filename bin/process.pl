#!/usr/bin/perl -I/home/bruce/git/BLA-XANES/lib  -I/home/bruce/git/XAS-Data-Interchange/perl/lib

use strict;
use warnings;
use Xray::BLA;
use File::Spec;
use Getopt::Long;

my $energy  = 9713;
my $verbose = 1;
my $save    = 0;
my $animate = 0;
my $inifile = q{}; # '/home/bruce/git/BLA-XANES/share/bla.xdi.ini'
my $result  = GetOptions ("energy|e=i"  => \$energy,
			  'save|s'      => \$save,
			  'animate|a'   => \$animate,
			  'verbose|v'   => \$verbose,
			  'inifile|i=s' => \$inifile,
			  'quiet|q'     => sub { $verbose = 0 },
			  'help|h'      => \&usage,
			 );

&usage if not $ARGV[0];

my $spectrum = Xray::BLA->new;
my $datalocation = '/home/bruce/Data/NIST/10ID/2011.12/';
$spectrum->set(scanfolder	  => File::Spec->catfile($datalocation, "scans"),
	       tiffolder	  => File::Spec->catfile($datalocation, "tiffs"),
	       outfolder	  => File::Spec->catfile($datalocation, "processed"),
	       stub		  => $ARGV[0],
	       peak_energy	  => $energy,
	       weak_pixel_value	  => 2,
	       social_pixel_value => 2,
	      );

$spectrum -> mask(save=>$save, verbose=>$verbose, animate=>$animate);
$spectrum -> scan(verbose=>$verbose, xdiini=>$inifile);


#my @elastic = (9703, 9705, 9707, 9709, 9711, 9713, 9715, 9717, 9719);
#foreach my $e (@elastic) {
#$spectrum -> peak_energy($e);

#foreach my $t (qw(0 2 4 6 8 14 20)) {
#  my $stub = sprintf("Au3PlectonemaT%s", $t);
#  $spectrum -> stub($stub);

#};


sub usage {
  print "
  herfd [options] <stub>

     energy  | e         emission energy
     animate | a         save tiff animation of mask creation
     save    | s         save intermediate steps of mask creation
     verbose | v         write progress messages
     quiet   | q         suppress progress messages

  This script assumes that scan files and image files have related names.

  example:  herfd -e 9713 -a Aufoil1

  In this example, the scan file is called `Aufoil1.001' and the image
  files are called `Aufoil1_NNNNN.tif'.

";
  exit;
};
