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
				#'MooseX::MutatorAttributes' => 0,
				'MooseX::AttributeHelpers'  => 0,
				'MooseX::Aliases'           => '0',
				'Config::IniFiles'          => 0,
				'Math::Round'               => 0,
				#'Xray::XDI'                 => 0,
				'Statistics::Descriptive'   => 0,
				'Term::Sk'                  => '0.07',
			       },
	 recommends         => {
				'Image::Magick'             => 0,
				'Imager'                    => 0.87,
			       },
	 sign               => 1,
	);
$build->create_build_script;

