set term wxt 1 font 'Droid Sans,9' enhanced

set auto
set key default
set pm3d map

set title '{/=14 Aufoil1 energy map}' offset 0,-5
set ylabel '{/=11 columns}' offset 0,2.5
#set xlabel '{/=11 rows}' rotate by 90

set view 0,90,1,1
set origin -0.17,-0.2
set size 1.4,1.4
unset grid

unset ztics
unset zlabel
set xrange [0:194]
set yrange [0:486]
set cbtics 9701, 4, 9721
set cbrange [9701:9721]

set colorbox vertical size 0.025,0.7 user origin 0.03,0.15

set palette model RGB defined (0 '#990000', 1 'red', 2 'orange', 3 'yellow', 4 'green', 5 '#009900', 6 '#006633', 7 '#0066DD', 8 '#000099')

splot '/home/bruce/Data/NIST/10ID/2011.12/processed/Aufoil1.map' title ''
