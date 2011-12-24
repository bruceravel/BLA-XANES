#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build
  -> new(
	 module_name        => 'Xray::BLA',
	 create_readme      => 0,
	 license            => 'perl',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 requires           => {
				'Moose'			    => '1.21',
				'MooseX::Aliases'           => '0.08',
				'MooseX::AttributeHelpers'  => '0.23',
				'MooseX::StrictConstructor' => '0.12',
				'Image::Magick'             => 0,
				#'Xray::XDI'                 => 0,
			       },
	 sign               => 1,
	);
$build->create_build_script;

