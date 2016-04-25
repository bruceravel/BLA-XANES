package Xray::BLA::SplotPalette;

=for Copyright
 .
 Copyright (c) 2016 Bruce Ravel, Jeremy Kropf.
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
#use Encode;
use base qw( Exporter );
our @EXPORT_OK = qw($moreland $parula $kindlemann $blackbody $jet $pm3d);

# Matlab color map parula, see:
# http://www.mathworks.de/products/matlab/matlab-graphics/#new_look_for_matlab_graphics
# http://www.gnuplotting.org/matlab-colorbar-parula-with-gnuplot/
our $parula = 'defined (\
 0    0.2081    0.1663    0.5292,\
 1    0.2116    0.1898    0.5777,\
 2    0.2123    0.2138    0.6270,\
 3    0.2081    0.2386    0.6771,\
 4    0.1959    0.2645    0.7279,\
 5    0.1707    0.2919    0.7792,\
 6    0.1253    0.3242    0.8303,\
 7    0.0591    0.3598    0.8683,\
 8    0.0117    0.3875    0.8820,\
 9    0.0060    0.4086    0.8828,\
10    0.0165    0.4266    0.8786,\
11    0.0329    0.4430    0.8720,\
12    0.0498    0.4586    0.8641,\
13    0.0629    0.4737    0.8554,\
14    0.0723    0.4887    0.8467,\
15    0.0779    0.5040    0.8384,\
16    0.0793    0.5200    0.8312,\
17    0.0749    0.5375    0.8263,\
18    0.0641    0.5570    0.8240,\
19    0.0488    0.5772    0.8228,\
20    0.0343    0.5966    0.8199,\
21    0.0265    0.6137    0.8135,\
22    0.0239    0.6287    0.8038,\
23    0.0231    0.6418    0.7913,\
24    0.0228    0.6535    0.7768,\
25    0.0267    0.6642    0.7607,\
26    0.0384    0.6743    0.7436,\
27    0.0590    0.6838    0.7254,\
28    0.0843    0.6928    0.7062,\
29    0.1133    0.7015    0.6859,\
30    0.1453    0.7098    0.6646,\
31    0.1801    0.7177    0.6424,\
32    0.2178    0.7250    0.6193,\
33    0.2586    0.7317    0.5954,\
34    0.3022    0.7376    0.5712,\
35    0.3482    0.7424    0.5473,\
36    0.3953    0.7459    0.5244,\
37    0.4420    0.7481    0.5033,\
38    0.4871    0.7491    0.4840,\
39    0.5300    0.7491    0.4661,\
40    0.5709    0.7485    0.4494,\
41    0.6099    0.7473    0.4337,\
42    0.6473    0.7456    0.4188,\
43    0.6834    0.7435    0.4044,\
44    0.7184    0.7411    0.3905,\
45    0.7525    0.7384    0.3768,\
46    0.7858    0.7356    0.3633,\
47    0.8185    0.7327    0.3498,\
48    0.8507    0.7299    0.3360,\
49    0.8824    0.7274    0.3217,\
50    0.9139    0.7258    0.3063,\
51    0.9450    0.7261    0.2886,\
52    0.9739    0.7314    0.2666,\
53    0.9938    0.7455    0.2403,\
54    0.9990    0.7653    0.2164,\
55    0.9955    0.7861    0.1967,\
56    0.9880    0.8066    0.1794,\
57    0.9789    0.8271    0.1633,\
58    0.9697    0.8481    0.1475,\
59    0.9626    0.8705    0.1309,\
60    0.9589    0.8949    0.1132,\
61    0.9598    0.9218    0.0948,\
62    0.9661    0.9514    0.0755,\
63    0.9763    0.9831    0.0538)';

# New default color palette after Moreland (2009)
# see: http://www.sandia.gov/~kmorel/documents/ColorMaps/
# For the gnuplot implementation have a look at
# http://bastian.rieck.ru/blog/posts/2012/gnuplot_better_colour_palettes/
# http://www.gnuplotting.org/default-color-map/
our $moreland = 'defined (\
0       0.2314  0.2980  0.7529,\
0.03125 0.2667  0.3529  0.8000,\
0.0625  0.3020  0.4078  0.8431,\
0.09375 0.3412  0.4588  0.8824,\
0.125   0.3843  0.5098  0.9176,\
0.15625 0.4235  0.5569  0.9451,\
0.1875  0.4667  0.6039  0.9686,\
0.21875 0.5098  0.6471  0.9843,\
0.25    0.5529  0.6902  0.9961,\
0.28125 0.5961  0.7255  1.0000,\
0.3125  0.6392  0.7608  1.0000,\
0.34375 0.6824  0.7882  0.9922,\
0.375   0.7216  0.8157  0.9765,\
0.40625 0.7608  0.8353  0.9569,\
0.4375  0.8000  0.8510  0.9333,\
0.46875 0.8353  0.8588  0.9020,\
0.5     0.8667  0.8667  0.8667,\
0.53125 0.8980  0.8471  0.8196,\
0.5625  0.9255  0.8275  0.7725,\
0.59375 0.9451  0.8000  0.7255,\
0.625   0.9608  0.7686  0.6784,\
0.65625 0.9686  0.7333  0.6275,\
0.6875  0.9686  0.6941  0.5804,\
0.71875 0.9686  0.6510  0.5294,\
0.75    0.9569  0.6039  0.4824,\
0.78125 0.9451  0.5529  0.4353,\
0.8125  0.9255  0.4980  0.3882,\
0.84375 0.8980  0.4392  0.3451,\
0.875   0.8706  0.3765  0.3020,\
0.90625 0.8353  0.3137  0.2588,\
0.9375  0.7961  0.2431  0.2196,\
0.96875 0.7529  0.1569  0.1843,\
1       0.7059  0.0157  0.1490\
)';

# http://www.kennethmoreland.com/color-advice/
our $kindlemann = 'defined (\
0.00000    0.0000    0.0000    0.0000,\
0.03226    0.1098    0.0039    0.1137,\
0.06452    0.1529    0.0118    0.2078,\
0.09677    0.1765    0.0157    0.2902,\
0.12903    0.1961    0.0196    0.3804,\
0.16129    0.2157    0.0235    0.4706,\
0.19355    0.2431    0.0275    0.5529,\
0.22581    0.2471    0.0314    0.6627,\
0.25806    0.0392    0.1020    0.8196,\
0.29032    0.0314    0.2353    0.6824,\
0.32258    0.0275    0.3059    0.5686,\
0.35484    0.0235    0.3569    0.4863,\
0.38710    0.0196    0.4000    0.4314,\
0.41935    0.0196    0.4392    0.3922,\
0.45161    0.0235    0.4784    0.3490,\
0.48387    0.0235    0.5176    0.2980,\
0.51613    0.0275    0.5569    0.2392,\
0.54839    0.0275    0.5961    0.1765,\
0.58065    0.0314    0.6353    0.1216,\
0.61290    0.0314    0.6745    0.0980,\
0.64516    0.0431    0.7137    0.0353,\
0.67742    0.2275    0.7412    0.0353,\
0.70968    0.3765    0.7686    0.0353,\
0.74194    0.5176    0.7882    0.0392,\
0.77419    0.6588    0.8039    0.0392,\
0.80645    0.7961    0.8118    0.0392,\
0.83871    0.9529    0.8039    0.0471,\
0.87097    0.9804    0.8275    0.6314,\
0.90323    0.9882    0.8667    0.7843,\
0.93548    0.9922    0.9098    0.8745,\
0.96774    0.9961    0.9529    0.9412,\
1.00000    1.0000    1.0000    1.0000\
)';

# http://www.kennethmoreland.com/color-advice/
our $blackbody = 'defined (\
0.0              0.0                     0.0                     0.0,\
0.0322580        0.0857913205762         0.0309874526184         0.0173328711915,\
0.0645161        0.133174636606          0.0588688899571         0.0346802666087,\
0.0967741        0.180001956037          0.0730689545154         0.0515393237212,\
0.1290322        0.22981556179           0.0840603593119         0.0647813713857,\
0.1612903        0.281397607223          0.093912584278          0.075408501413,\
0.1935483        0.334521638801          0.102639499627          0.0842454688083,\
0.2258064        0.388957802186          0.110254429637          0.0927990674821,\
0.2580645        0.444611925648          0.116732501721          0.101402659637,\
0.2903225        0.501422312285          0.122025816585          0.110058408122,\
0.3225806        0.559331322331          0.126067584009          0.118767796491,\
0.3548387        0.618285970576          0.128767919785          0.127531801155,\
0.3870967        0.678237857955          0.130007052818          0.136351016263,\
0.4193548        0.712849583079          0.181721849923          0.13081678256,\
0.4516129        0.743632057947          0.232649759358          0.120991817028,\
0.4838709        0.774324938583          0.279315911516          0.108089917959,\
0.5161290        0.804936242903          0.323627020047          0.0907961686083,\
0.5483870        0.835473266757          0.366524681419          0.0662363460741,\
0.5806451        0.865942668698          0.408541395043          0.026029485466,\
0.6129032        0.876634426153          0.46401951695           0.0173065426095,\
0.6451612        0.883455346031          0.518983528803          0.0149628730405,\
0.6774193        0.88905246237           0.572164381169          0.013499801006,\
0.7096774        0.893375939063          0.624108797455          0.0130334871745,\
0.7419354        0.89637036663           0.675180034619          0.013680092215,\
0.7741935        0.897973818846          0.725630730259          0.015555776796,\
0.8064516        0.898116710502          0.775642817733          0.0187767015864,\
0.8387096        0.896720396485          0.825350944866          0.023459027255,\
0.8709677        0.927670131094          0.859991226192          0.319086199143,\
0.9032258        0.956158602738          0.893933112845          0.503316730316,\
0.9354838        0.97827065392           0.92856476667           0.671307024002,\
0.9677419        0.993196411712          0.963913323002          0.83560909192,\
1.0              1.0                     1.0                     1.0\
)';


## http://www.gnuplotting.org/matlab-colorbar-with-gnuplot/
our $jet = "defined ( 0 '#000090',\\
                      1 '#000fff',\\
                      2 '#0090ff',\\
                      3 '#0fffee',\\
                      4 '#90ff70',\\
                      5 '#ffee00',\\
                      6 '#ff7000',\\
                      7 '#ee0000',\\
                      8 '#7f0000')";

our $pm3d = 'rgbformulae 7,5,15';


1;

=head1 NAME

Xray::BLA::SplotPalette - A repository of gnuplot surface plot palette definitions

=head1 VERSION

See Xray::BLA

=head1 STNOPSIS

This exports several constants containing strings which define useful
Gnuplot palettes.

   use Xray::BLA::SplotPalette qw($moreland $parula $kindlemann $blackbody $jet $pm3d);

=head1 PALETTES

=over 4

=item C<parula>

The default palette.  This implements the Matlab parula colormap.  See
http://www.gnuplotting.org/matlab-colorbar-parula-with-gnuplot/

This is a blue to yellow colormap with fairly uniform intensity
variation over the scale.

=item C<moreland>

This is Kenneth Moreland's "smooth cool warm" colormap.  See
http://www.kennethmoreland.com/color-advice/

=item C<kindlemann>

This is Kenneth Moreland's implementation of the Kindlemann color map,
a rainbow color map with the luminance adjusted such that it
monotonically changes over the full scale.  See
http://www.kennethmoreland.com/color-advice/ and
http://www.cs.utah.edu/~gk/papers/vis02/

=item C<blackbody>

This is Kenneth Moreland's colormap based on the colors of black body
radiation.  See http://www.kennethmoreland.com/color-advice/

=item C<jet>

This is the Matlab rainbow colormap.  Your humble author dislikes this
colormap, but it's a popular one.

=item C<pm3d>

This is Gnuplot default color map.

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
