#!/usr/bin/perl

use strict;
use warnings;
use autodie qw(open close);
use Image::Magick;

my $tif = "tiffs/Au3MarineCyanos1_elastic_9715_00001.tif";
my $p = Image::Magick->new();
$p->Read(filename=>$tif);
print $p->Get('version'), $/;
my $columns = $p->Get('columns');
my $rows = $p->Get('rows');

my $cutoff = 500;
my $small  = 3;

######################################################################
## remove bad or weak pixels

my $removed  = 0;
my $toosmall = 0;
my ($on, $off) = (0,0);
foreach my $co (0 .. $columns-1) {
  foreach my $ro (0 .. $rows-1) {
    my $str = $p->Get("pixel[$co,$ro]");
    my @pix = split(/,/, $str);
#    print "$co, $ro: $pix[0]\n" if $pix[0]>5;
    if ($pix[0] > $cutoff) {
      $p->Set("pixel[$co,$ro]"=>0);
      ++$removed;
      ++$off;
    } elsif ($pix[0] < $small) {
      $p->Set("pixel[$co,$ro]"=>0);
      ++$toosmall;
      ++$off;
    } else {
      if ($pix[0]) {++$on} else {++$off};
    };
  };
};
print "first pass\n";
print "\tRemoved $removed bad pixels and $toosmall weak pixels\n";
printf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
  $on, $off, $on+$off;



######################################################################
## remove lonely pixels

$removed = 0;
$on      = 0;
$off     = 0;
foreach my $co (0 .. $columns-1) {
  foreach my $ro (0 .. $rows-1) {

    my $str = $p->Get("pixel[$co,$ro]");
    my @pix = split(/,/, $str);

    if ($pix[0] == 0) {
      ++$off;
      next;
    };

    my $count = 0;
    foreach my $cc (-1 .. 1) {
      next if (($co == 0) and ($cc == -1));
      next if (($co == $columns-1) and ($cc == 1));
      foreach my $rr (-1 .. 1) {
	next if (($cc == 0) and ($rr == 0));
	next if (($ro == 0) and ($rr == -1));
	next if (($ro == $rows-1) and ($rr == 1));

	my $arg = sprintf("pixel[%d,%d]", $co+$cc, $ro+$rr);
	$str = $p->Get($arg);
	my @neighbor = split(/,/, $str);

	++$count if ($neighbor[0] > 0);
      };
    };
    if ($count<3) {
      $p->Set("pixel[$co,$ro]"=>0);
      ++$removed;
      ++$off;
    } else {
      ++$on;
    };
  };
};
print "second pass\n";
print "\tRemoved $removed lonely pixels\n";
printf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
  $on, $off, $on+$off;



######################################################################
## add social pixels

my $added = 0;
$on    = 0;
$off   = 0;
my @addlist = ();
foreach my $co (0 .. $columns-1) {
  foreach my $ro (0 .. $rows-1) {

    my $str = $p->Get("pixel[$co,$ro]");
    my @pix = split(/,/, $str);

    if ($pix[0] > 0) {
      ++$on;
      next;
    };

    my $count = 0;
    foreach my $cc (-1 .. 1) {
      next if (($co == 0) and ($cc == -1));
      next if (($co == $columns-1) and ($cc == 1));
      foreach my $rr (-1 .. 1) {
	next if (($cc == 0) and ($rr == 0));
	next if (($ro == 0) and ($rr == -1));
	next if (($ro == $rows-1) and ($rr == 1));

	my $arg = sprintf("pixel[%d,%d]", $co+$cc, $ro+$rr);
	$str = $p->Get($arg);
	my @neighbor = split(/,/, $str);

	++$count if ($neighbor[0] > 0);
      };
    };
    if ($count>2) {
      push @addlist, [$co, $ro];
      ++$added;
      ++$on;
    } else {
      ++$off;
    };
  };
};
foreach my $px (@addlist) {
  my $arg = sprintf("pixel[%d,%d]", $px->[0], $px->[1]);
  $p->Set($arg=>'5,5,5,0');
};

print "third pass\n";
print "\tAdded $added social pixels\n";
printf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
  $on, $off, $on+$off;


$p->Write(filename=>"foo.tif", geometry=>$columns.'x'.$rows);
print "Wrote foo.tif\n";

