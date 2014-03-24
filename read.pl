#!/usr/bin/perl

use strict;
#use warnings;
use PDL;
use PDL::Graphics::Simple;
use PDL::Graphics::Gnuplot qw(gplot image);
use PDL::IO::FlexRaw;
use PDL::NiceSlice;

my $file = '/home/bruce/Data/NIST/10ID/Jeremy/foil/Pd_foil_HERFD_Ka_1fix_elastic_21176_0001.tif';


use Inline C => Config => LIBS => '-ltiff';
use Inline C => <<'END';
  #include <tiffio.h>
  void tvx_img_size (const char *file) {
    TIFF *tif=TIFFOpen(file, "r");
    uint32 width, height;
    TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
    TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);
    TIFFClose(tif);
    
    Inline_Stack_Vars;
Inline_Stack_Reset;
Inline_Stack_Push(sv_2mortal(newSViv(width)));
Inline_Stack_Push(sv_2mortal(newSViv(height)));
Inline_Stack_Done;
  }
END

my ($width,$height) = tvx_img_size($file);
print "width = $width\nheight = $height\n";


my $bytes =  -s $file;
my $longs = $bytes / 4;

my $img = readflex($file, [ { Type=>'long', NDims=>1, Dims=>[$longs] } ]);

my $im2d = $img(1024:-1)->splitdim(0,487);
$im2d->badflag(1);
#$im2d->inplace->setvaltobad(0);

print $im2d -> max, $/;
print $im2d -> min, $/;
print $im2d -> at(73,14), $/;

#imag($im2d, 0, 5);
  image({cbrange=>[0,10], palette=>"defined ( 0 '#252525', 1 '#525252', 2 '#737373', 3 '#969696', 4 '#BDBDBD', 5 '#D9D9D9', 6 '#F0F0F0', 7 '#FFFFFF' )",
	 xlabel=>'pixels (width)', ylabel=>'pixels (height)', cblabel=>'counts'},
	$im2d);

print "Return to continue>";
<>;
