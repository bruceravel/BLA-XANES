package Demeter::UI::Metis::Config;

use strict;
use warnings;

use Cwd;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_COMBOBOX EVT_BUTTON);

use Graphics::Gnuplot::Palettes qw(palette_names);


use Demeter::UI::Wx::Config;

sub new {
  my ($class, $page, $app) = @_;
  my $top = $page->GetParent;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($hbox, 0, wxGROW|wxTOP|wxBOTTOM, 5);

  $self->{title} = Wx::StaticText->new($self, -1, "Configuration");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $hbox ->  Add($self->{title}, 1, wxGROW|wxALL, 5);

  $self->{save} = Wx::BitmapButton->new($self, -1, $app->{save_icon});
  $hbox ->  Add($self->{save}, 0, wxALL, 5);
  EVT_BUTTON($self, $self->{save}, sub{Demeter::UI::Metis->save_hdf5(@_, $app)});
  $app->mouseover($self->{save}, "Save this project to an HDF5 file.");


  my $config = Demeter::UI::Wx::Config->new($self, \&target, $::app->{main});
  $config->{echo} = $app->{main}->{statusbar};
  Demeter->co->set_options('metis', 'splot_palette_name', [palette_names()], 1);
  $config->populate(['metis', 'gnuplot']);
#  $config->{params}->Expand($self->{params}->GetRootItem);
  $vbox->Add($config, 1, wxGROW|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;
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

