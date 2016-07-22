package Demeter::UI::Metis::Config;

use strict;
use warnings;

use Cwd;

use Wx qw( :everything );
#use base 'Wx::Panel';
use Wx::Event qw(EVT_COMBOBOX EVT_BUTTON);

use Graphics::Gnuplot::Palettes qw(palette_names);


use base 'Demeter::UI::Wx::Config';

sub new {
  my ($class, $page, $app) = @_;
  my $top = $page->GetParent;
  my $self = $class->SUPER::new($page, \&target, $top);
  $self->{echo} = $app->{main}->{statusbar};
  Demeter->co->set_options('metis', 'splot_palette_name', [palette_names()], 1);
  $self->populate(['metis', 'gnuplot']);
  $self->{params}->Expand($self->{params}->GetRootItem);

  return $self;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;

  #foreach my $p (qw(polyfill_order imagescale xdi_metadata_file tiffcounter terminal
  #		    energycounterwidth gaussian_kernel splot_palette_name color outimage
  #		    image_file_template scan_file_template elastic_file_template)) {
  $::app->set_parameters;
  ($save)
    ? $self->{echo}->SetStatusText("Now using $value for $parent-->$param and configuration was saved")
      : $self->{echo}->SetStatusText("Now using $value for $parent-->$param");

};


1;


=head1 NAME

Demeter::UI::Metis::Config - Metis' configuration tool

=head1 VERSION

This documentation refers to Xray::BLA version 2.

=head1 DESCRIPTION

Metis is a graphical interface the Xray::BLA package for processing
data from an energy dispersive bent Laue analyzer spectrometer in
which the signal is dispersed onto the face of a Pilatus camera.

The Config tool is used to set various parameters that are not set on
other tools.  Setting the parameters also writes a save file for Metis
to use the next time it starts up.

=head1 DEPENDENCIES

Xray::BLA and Metis's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems as issues at the github site
L<https://github.com/bruceravel/BLA-XANES>

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

