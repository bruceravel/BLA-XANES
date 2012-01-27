#!/usr/bin/perl
use Test::More tests => 2;
use warnings;
no warnings qw(redefine);

eval 'require Xray::BLA;';
ok((not $@), 'Xray::BLA imports correctly.');

my $spectrum = Xray::BLA->new;
ok( defined($spectrum) && blessed $spectrum eq 'Xray::BLA',     'new() works' );
