package Demeter::UI::Metis::Files;

use strict;
use warnings;

use Cwd;
use Chemistry::Elements qw(get_Z get_symbol);
use File::Basename;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LISTBOX_DCLICK EVT_BUTTON  EVT_KEY_DOWN);

sub new {
  my ($class, $page, $app) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{title} = Wx::StaticText->new($self, -1, "Import files");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );

  $vbox ->  Add($self->{title}, 0, wxGROW|wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5,5 );

  my @elements = map {sprintf "%s: %s", $_, get_symbol($_)} (1 .. 96);
  my $stub    = $app->{spectrum}->stub    || q{};
  my $element = $app->{spectrum}->element || q{};
  my $line    = $app->{spectrum}->line    || q{};
  $self->{stub_label}    = Wx::StaticText -> new($self, -1, "File stub");
  $self->{stub}          = Wx::TextCtrl   -> new($self, -1, $stub, wxDefaultPosition, [150,-1]);
  $self->{element_label} = Wx::StaticText -> new($self, -1, "Element");
  $self->{element}       = Wx::ComboBox   -> new($self, -1, q{}, wxDefaultPosition, [100,-1], \@elements, wxCB_READONLY);
  $self->{line_label}    = Wx::StaticText -> new($self, -1, "Line");
  $self->{line}          = Wx::ComboBox   -> new($self, -1, $line, wxDefaultPosition, [80,-1], [qw(Ka1 Ka2 Kb2 Kb2 Kb3 La1 La2 Lb1 Lb2 Lb3 Lb4 Lg1 Lg2 Lg3 Ll)], wxCB_READONLY);
  $gbs -> Add($self->{stub_label},    Wx::GBPosition->new(0,0));
  $gbs -> Add($self->{stub},          Wx::GBPosition->new(0,1));
  $gbs -> Add($self->{element_label}, Wx::GBPosition->new(0,2));
  $gbs -> Add($self->{element},       Wx::GBPosition->new(0,3));
  $gbs -> Add($self->{line_label},    Wx::GBPosition->new(0,4));
  $gbs -> Add($self->{line},          Wx::GBPosition->new(0,5));
  $self->{element}->SetSelection(get_Z($element)-1) if $element;
  $self->{line}->SetStringSelection($line);
  $app->mouseover($self->{stub}, "Specify the base of the scan and image filenames.");
  $app->mouseover($self->{element}, "Specify the absorber element.");
  $app->mouseover($self->{stub}, "Specify the measured emission line.");

  my $icon = File::Spec->catfile(dirname($INC{"Demeter/UI/Metis.pm"}), 'Metis', , 'share', "metis_logo.png");
  my $logo = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);
  $gbs -> Add(Wx::StaticText->new($self, -1, q{ }, wxDefaultPosition, [50,-1]),
	      Wx::GBPosition->new(0,6));
  $gbs -> Add(Wx::StaticBitmap->new($self, -1, $logo, wxDefaultPosition, [100,100]),
	      Wx::GBPosition->new(0,7), Wx::GBSpan->new(4,1));


  my $scanfolder = $app->{spectrum}->scanfolder || q{};
  $self->{scan_label} = Wx::StaticText -> new($self, -1, "Scan folder");
  $self->{scan} = Wx::TextCtrl->new($self, -1, $scanfolder, wxDefaultPosition, [500,-1],);
  $gbs -> Add($self->{scan_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($self->{scan},       Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,5));
  $app->mouseover($self->{scan}, "Specify the location of the scan files.");

  my $tifffolder = $app->{spectrum}->tifffolder || q{};
  $self->{image_label} = Wx::StaticText -> new($self, -1, "Image folder");
  $self->{image} = Wx::TextCtrl->new($self, -1, $tifffolder, wxDefaultPosition, [500,-1],);
  $gbs -> Add($self->{image_label}, Wx::GBPosition->new(2,0));
  $gbs -> Add($self->{image},       Wx::GBPosition->new(2,1), Wx::GBSpan->new(1,5));
  $app->mouseover($self->{image}, "Specify the location of the image files.");

  $self->{fetch} = Wx::Button->new($self, -1, "&Fetch file lists");
  $gbs -> Add($self->{fetch},       Wx::GBPosition->new(3,1));
  $app->mouseover($self->{image}, "Fetch all image files and populate the file lists below.");

  $vbox -> Add($gbs, 0, wxGROW|wxALL, 5);

  EVT_BUTTON($self, $self->{fetch}, sub{fetch(@_, $app)});

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my $elasticbox       = Wx::StaticBox->new($self, -1, 'Elastic files', wxDefaultPosition, wxDefaultSize);
  my $elasticboxsizer  = Wx::StaticBoxSizer->new( $elasticbox, wxVERTICAL );

  $self->{elastic_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $elasticboxsizer -> Add($self->{elastic_list}, 1, wxGROW);
  $hbox -> Add($elasticboxsizer, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX_DCLICK($self, $self->{elastic_list}, sub{view(@_, $app, 'elastic')});
  $app->mouseover($self->{elastic_list}, "Double click to display an elastic image file.");

  my $imagebox       = Wx::StaticBox->new($self, -1, 'Image files', wxDefaultPosition, wxDefaultSize);
  my $imageboxsizer  = Wx::StaticBoxSizer->new( $imagebox, wxVERTICAL );

  $self->{image_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $imageboxsizer -> Add($self->{image_list}, 1, wxGROW);
  $hbox -> Add($imageboxsizer, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX_DCLICK($self, $self->{image_list}, sub{view(@_, $app, 'image')});
  $app->mouseover($self->{image_list}, "Double click to display the image file for a data point.");

  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub fetch {
  my ($self, $event, $app) = @_;
  my $stub           = $self->{stub}->GetValue;
  my $scan_folder    = $self->{scan}->GetValue;
  my $image_folder   = $self->{image}->GetValue;
  #print join("\n", $stub, $scan_folder, $elastic_folder, $image_folder), $/;

  $app->set_parameters;
  $app->{spectrum} -> clear_elastic_energies;
  $app->{spectrum} -> stub($stub);

  opendir(my $E, $image_folder);
  my @elastic_list = sort {$a cmp $b} grep {$_ =~ m{$stub}} (grep {$_ =~ m{elastic}} (grep {$_ =~ m{.tif\z}} readdir $E));
  closedir $E;
  #print join($/, @elastic_list), $/;
  $self->{elastic_list}->Clear;
  $self->{elastic_list}->InsertItems(\@elastic_list,0);

  opendir(my $I, $image_folder);
  my @image_list = sort {$a cmp $b} grep {$_ =~ m{$stub}} (grep {$_ !~ m{elastic}} (grep {$_ =~ m{.tif\z}} readdir $I));
  closedir $I;
  #print join($/, @image_list), $/;
  $self->{image_list}->Clear;
  $self->{image_list}->InsertItems(\@image_list,0);

  foreach my $e (@elastic_list) {
    ($e =~ m{elastic_(\d+)_}) and
      $app->{spectrum}->push_elastic_energies($1);
  };


  foreach my $k (qw(stub energylabel energy)) {
    $app->{Mask}->{$k} -> Enable(1);
  };
  $app->{Mask}->{stub} -> SetLabel("Stub is \"$stub\"");
  $app->{Mask}->{energy} -> Clear;
  $app->{Mask}->{energy} -> Append($_) foreach @{$app->{spectrum}->elastic_energies};

  $app->{main}->status("Found elastic and image files for $stub");

};

sub view {
  my ($self, $event, $app, $which) = @_;
  my $stub   = $self->{stub}->GetValue;
  my $folder = $self->{image}->GetValue;
  my $img    = $self->{$which."_list"} -> GetStringSelection;
  my $file   = File::Spec->catfile($folder, $img);

  if ($which eq 'image') {
    $app->{spectrum}->plot_energy_point($file);
    $app->{main}->status("Plotted energy point $file");
    return;
  };

  $app->{spectrum} -> tifffolder($folder);
  $app->{spectrum} -> stub($stub);
  if ($file =~ m{elastic_(\d+)_}) {
    $app->{spectrum} -> energy($1);
  } else {
    $app->{main}->status("Can't figure out energy...", 'alert');
    return;
  };

  $app->{spectrum}->elastic_file($file);
  my $ret = $app->{spectrum}->check($img);
  if ($ret->status == 0) {
     $app->{main}->status($ret->message, 'alert');
     return;
  };

  my $cbm = int($app->{spectrum}->elastic_image->max);
  if ($cbm < 1) {
    $cbm = 1;
  } elsif ($cbm > $app->{spectrum}->bad_pixel_value/$app->{spectrum}->imagescale) {
    $cbm = $app->{spectrum}->bad_pixel_value/$app->{spectrum}->imagescale;
  };
  $app->{spectrum}->cbmax($cbm);# if $step =~ m{social};
  $app->{spectrum}->plot_mask;
  $app->{main}->status("Plotted ".$app->{spectrum}->elastic_file);

};

1;


=head1 NAME

Demeter::UI::Metis::Files - Metis' file organization tool

=head1 VERSION

This documentation refers to Xray::BLA version 1.

=head1 DESCRIPTION

Metis is a graphical interface the Xray::BLA package for processing
data from an energy dispersive bent Laue analyzer spectrometer in
which the signal is dispersed onto the face of a Pilatus camera.

The Files tool is used to organize the mountain of images from the
Pilatus and to prepare for further data processing.  This tool also
facilitates visualization of the raw images.

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

