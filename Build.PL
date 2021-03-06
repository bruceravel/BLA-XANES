#!/usr/bin/perl
use strict;
use warnings;
use BLABuilder;

my $build = BLABuilder
  -> new(
	 module_name        => 'Xray::BLA',
	 create_readme      => 0,
	 license            => 'perl',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 requires           => {
				'perl'                      => '5.10.0',
				'PDL'                       => '0',
				'PDL::IO::HDF5'             => '0.73',
				'Moose'			    => '1.21',
				'MooseX::Aliases'           => '0',
				'Config::IniFiles'          =>  0,
				'Image::Info'               =>  1.38,
				'File::Slurper'             =>  0,
				'List::Compare'             =>  0,
				'Math::Random'              =>  0,
				'Math::Round'               =>  0,
				#'Xray::XDI'                 => 0,
				'Term::Sk'                  => '0.07',
				'Text::Template'            =>  0,
				'YAML::Tiny'                =>  0,
				'Graphics::Gnuplot::Palettes' => 0,
			       },
	 recommends         => {
				'PDL::Graphics::Simple'     =>  0,
				'PDL::Graphics::Gnuplot'    =>  '2.006',
				#'Pod::POM::View::Restructured' => 0,
	 		       },
	 sign               => 1,
	);
$build->add_build_element('demeter_conf');
$build->add_build_element('ico');
$build->add_build_element('ini');
$build->add_build_element('png');
$build->create_build_script;
