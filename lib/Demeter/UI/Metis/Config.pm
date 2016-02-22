package Demeter::UI::Metis::Config;

use strict;
use warnings;

use Cwd;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_COMBOBOX EVT_BUTTON);

sub new {
  my ($class, $page, $app) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{title} = Wx::StaticText->new($self, -1, "Configuration");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox ->  Add($self->{title}, 0, wxGROW|wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5,5 );
  $vbox ->  Add($gbs, 0, wxGROW|wxALL, 5);
  my $row = -1;

  ++$row;
  $self->{imagescale_label} = Wx::StaticText -> new($self, -1, "Scaling factor for image plots");
  $self->{imagescale}       = Wx::TextCtrl   -> new($self, -1, $app->{base}->imagescale, wxDefaultPosition, [175,-1]);
  $gbs -> Add($self->{imagescale_label},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{imagescale},          Wx::GBPosition->new($row,1));
  $app->mouseover($self->{imagescale}, "This sets the colorbar scale of an image plot.  Bigger number -> smaller dynamic range.");
  $gbs -> Add(Wx::StaticText->new($self, -1, '     '), Wx::GBPosition->new($row,2));

  #++$row;
  $self->{color_label} = Wx::StaticText -> new($self, -1, "Image color");
  $self->{color}       = Wx::Choice     -> new($self, -1, wxDefaultPosition, wxDefaultSize, [qw(grey green blue orange purple red), 'Surprise me!']);
  $gbs -> Add($self->{color_label},    Wx::GBPosition->new($row,3));
  $gbs -> Add($self->{color},          Wx::GBPosition->new($row,4));
  $self->{color}->SetStringSelection($app->{base}->color);
  $app->mouseover($self->{color}, "The color palette used to plot mask images.");

  ++$row;
  $self->{tiffcounter_label} = Wx::StaticText -> new($self, -1, "TIFF counter");
  $self->{tiffcounter}       = Wx::TextCtrl   -> new($self, -1, $app->{base}->tiffcounter, wxDefaultPosition, [175,-1]);
  $gbs -> Add($self->{tiffcounter_label},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{tiffcounter},          Wx::GBPosition->new($row,1));
  $app->mouseover($self->{tiffcounter}, "The counter part of the name of the elastic TIFF file, eg the \"00001\" in \"Aufoil1_elastic_9713_00001.tif\".");

  #++$row;
  $self->{terminal_label} = Wx::StaticText -> new($self, -1, "Plotting terminal");
  $self->{terminal}       = Wx::Choice     -> new($self, -1, wxDefaultPosition, wxDefaultSize, [qw(wxt qt x11 aqua windows)]);
  $gbs -> Add($self->{terminal_label},    Wx::GBPosition->new($row,3));
  $gbs -> Add($self->{terminal},          Wx::GBPosition->new($row,4));
  $self->{terminal}->SetStringSelection($app->{base}->terminal);
  $app->mouseover($self->{terminal}, "The Gnuplot terminal type.");

  ++$row;
  $self->{energycounterwidth_label} = Wx::StaticText -> new($self, -1, "Energy index width");
  $self->{energycounterwidth}       = Wx::SpinCtrl   -> new($self, -1, $app->{base}->energycounterwidth, wxDefaultPosition, [175,-1], wxSP_ARROW_KEYS, 1, 6);
  $gbs -> Add($self->{energycounterwidth_label},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{energycounterwidth},          Wx::GBPosition->new($row,1));
  $app->mouseover($self->{energycounterwidth}, "The width of the part of the energy point TIFF file name indicating the energy index, eg the 5 digits in \"Aufoil1_00040.tif\".");


  ##++$row;
  $self->{outimage_label} = Wx::StaticText -> new($self, -1, "Output image format");
  $self->{outimage}       = Wx::Choice     -> new($self, -1, wxDefaultPosition, wxDefaultSize, [qw(gif tif png)]);
  $gbs -> Add($self->{outimage_label},    Wx::GBPosition->new($row,3));
  $gbs -> Add($self->{outimage},          Wx::GBPosition->new($row,4));
  $self->{outimage}->SetStringSelection($app->{base}->outimage);
  $app->mouseover($self->{outimage}, "The file format used for static mask images.");


  ++$row;
  $self->{line} = Wx::StaticLine->new($self, -1, wxDefaultPosition, [100, 2], wxLI_HORIZONTAL);
  $gbs -> Add($self->{line}, Wx::GBPosition->new($row,0), Wx::GBSpan->new(1,4));

  ++$row;
  $self->{scan_file_template_label} = Wx::StaticText -> new($self, -1, "Scan file template");
  $self->{scan_file_template}       = Wx::TextCtrl   -> new($self, -1, $app->{base}->scan_file_template, wxDefaultPosition, [175,-1]);
  $gbs -> Add($self->{scan_file_template_label},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{scan_file_template},          Wx::GBPosition->new($row,1));
  $app->mouseover($self->{scan_file_template}, 'Scan file template: %s=stub, %e=emission energy, %i=incident energy, %t=tiffcounter, %c energy counter');

  ++$row;
  $self->{elastic_file_template_label} = Wx::StaticText -> new($self, -1, "Elastic image template");
  $self->{elastic_file_template}       = Wx::TextCtrl   -> new($self, -1, $app->{base}->elastic_file_template, wxDefaultPosition, [175,-1]);
  $gbs -> Add($self->{elastic_file_template_label},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{elastic_file_template},          Wx::GBPosition->new($row,1));
  $app->mouseover($self->{elastic_file_template}, 'Elastic file template: %s=stub, %e=emission energy, %i=incident energy, %t=tiffcounter, %c energy counter');

  ++$row;
  $self->{image_file_template_label} = Wx::StaticText -> new($self, -1, "Scan image template");
  $self->{image_file_template}       = Wx::TextCtrl   -> new($self, -1, $app->{base}->image_file_template, wxDefaultPosition, [175,-1]);
  $gbs -> Add($self->{image_file_template_label},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{image_file_template},          Wx::GBPosition->new($row,1));
  $app->mouseover($self->{image_file_template}, 'Image file template: %s=stub, %e=emission energy, %i=incident energy, %t=tiffcounter, %c energy counter');


  ++$row;
  $self->{xdi_metadata_file} = Wx::Button->new($self, -1, "&XDI metadata file", wxDefaultPosition, [140,-1]);
  $self->{xdi_filename} = Wx::StaticText -> new($self, -1, $app->{base}->xdi_metadata_file);
  EVT_BUTTON($self, $self->{xdi_metadata_file}, sub{SelectXDIFile(@_, $app)});
  $gbs -> Add($self->{xdi_metadata_file},    Wx::GBPosition->new($row,0));
  $gbs -> Add($self->{xdi_filename},         Wx::GBPosition->new($row,1), Wx::GBSpan->new(1,3));
  $app->mouseover($self->{xdi_metadata_file}, 'Select XDI metadata .ini file.');

  $vbox -> Add(1,30,0);

  $self->{set} = Wx::Button->new($self, -1, '&Set parameters');
  $vbox -> Add($self->{set}, 0, wxGROW|wxALL, 10);
  EVT_BUTTON($self, $self->{set}, sub{$app->set_parameters});
  $app->mouseover($self->{set}, "Set parameters and save Metis' current configuration.");

## image scaling factor
## tiffcounter
## energycounterwidth
## image format

  $self -> SetSizerAndFit( $vbox );

  return $self;
};


sub SelectXDIFile {
  my ($self, $event, $app) = @_;

  my $fd = Wx::FileDialog->new( $app->{main}, "Open XDI metadata file", cwd, q{},
				"INI (*.ini)|*.ini|All files (*)|*",
				wxFD_OPEN|wxFD_CHANGE_DIR|wxFD_FILE_MUST_EXIST, wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving data file canceled.");
    return;
  };

  my $file  = $fd->GetPath;
  $app->{Config}->{xdi_filename}->SetLabel($file);
  $app->{main}->status("Selected XDI metadata file: $file.");
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

Copyright (c) 2006-2014 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

