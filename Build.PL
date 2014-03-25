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
				'perl'                      => '5.10.0',
				'PDL'                       => '0',
				'Moose'			    => '1.21',
				'MooseX::Aliases'           => '0',
				'Config::IniFiles'          =>  0,
				'Math::Random'              =>  0,
				'Math::Round'               =>  0,
				#'Xray::XDI'                 => 0,
				'Term::Sk'                  => '0.07',
				'Text::Template'            =>  0,
				'YAML::Tiny'                =>  0,
			       },
	 recommends         => {
				'PDL::Graphics::Simple'     =>  0,
				'PDL::Graphics::Gnuplot'    =>  0,
	 		       },
	 sign               => 1,
	);
$build->add_build_element('png');
$build->add_build_element('ico');
$build->create_build_script;

