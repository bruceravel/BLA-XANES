set auto
set key default
set pm3d


## make a spare, square plot viewed from directly above
set view 0,90,1,1
set origin -0.17,-0.22
set size square 1.4,1.4
unset surface

unset ztics
unset zlabels
set xrange [0:194]
set yrange [0:486]
set cbtics 9701, 4, 9721
set cbrange [9701:9721]

set colorbox vertical size 0.025,0.45 user origin 0.02,0.3

#load 'tree_rings.gp'
set palette @MATLAB

splot 'map.dat'
