## tree trunks
hue(x) = x < 1./8. || x > 7./8. ? 0 : (8*x-1)/6.0
sat(x) = x < 3.0/16.0 || x > 15.0/16.0 ? 0 : (1+cos(8*2*pi*x))/2
lum(x) = x < 1.0/16.0 ? 0 : (1+cos(8*2*pi*x))/2
stp(x,y) = x < y ? 0 : 1
w = 0.89
set palette model HSV functions hue(gray), stp( sat(gray), w ), gray + (1-gray)*stp(lum(gray), w)
