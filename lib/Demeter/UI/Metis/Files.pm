package Demeter::UI::Metis::Files;

use strict;
use warnings;

use Cwd;
use Chemistry::Elements qw(get_Z get_symbol);
use File::Basename;
use Xray::Absorption;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LISTBOX_DCLICK EVT_BUTTON  EVT_KEY_DOWN EVT_CHECKBOX);

sub new {
  my ($class, $page, $app) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{title} = Wx::StaticText->new($self, -1, "Import files");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );

  $vbox ->  Add($self->{title}, 0, wxGROW|wxALL, 5);

  ## ------ stub, element, line ----------------------------------------
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($hbox, 0, wxGROW|wxTOP|wxBOTTOM, 5);

  my @elements = map {sprintf "%s: %s", $_, get_symbol($_)} (1 .. 96);
  my @lines = (qw(Ka1 Ka2 Kb2 Kb3 Kb4 Kb5 La1 La2 Lb1 Lb2 Lb3 Lb4 Lb5 Lb6 Lg1 Lg2 Lg3 Ll Ln));

  my $stub    = $app->{base}->stub    || q{};
  my $element = $app->{base}->element || q{};
  my $line    = $app->{base}->line    || q{};
  $self->{stub_label}    = Wx::StaticText -> new($self, -1, "File stub");
  $self->{stub}          = Wx::TextCtrl   -> new($self, -1, $stub, wxDefaultPosition, [200,-1]);
  $self->{element_label} = Wx::StaticText -> new($self, -1, "Element");
  $self->{element}       = Wx::ComboBox   -> new($self, -1, q{}, wxDefaultPosition, [100,-1], \@elements, wxCB_READONLY);
  $self->{line_label}    = Wx::StaticText -> new($self, -1, "Line");
  $self->{line}          = Wx::ComboBox   -> new($self, -1, $line, wxDefaultPosition, [80,-1], \@lines, wxCB_READONLY);
  $self->{div10}         = Wx::CheckBox   -> new($self, -1, "&Divide by 10");
  $self->{div10}        -> SetValue($app->{base}->div10);
  #$self->{scale24}       = Wx::CheckBox   -> new($self, -1, "&Scale by 2^-24");
  #$self->{scale24}      -> SetValue(0);
  $hbox -> Add($self->{stub_label},    0, wxLEFT|wxRIGHT|wxTOP, 3);
  $hbox -> Add($self->{stub},          0, wxLEFT|wxRIGHT, 5);
  $hbox -> Add($self->{element_label}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $hbox -> Add($self->{element},       0, wxLEFT|wxRIGHT, 5);
  $hbox -> Add($self->{line_label},    0, wxLEFT|wxRIGHT|wxTOP, 3);
  $hbox -> Add($self->{line},          0, wxLEFT|wxRIGHT, 5);
  $hbox -> Add($self->{div10},         0, wxLEFT|wxRIGHT, 5);
  #$hbox -> Add($self->{scale24},       0, wxLEFT|wxRIGHT, 5);
  $self->{element}->SetSelection(get_Z($element)-1) if $element;
  $self->{line}->SetStringSelection($line);
  $app->mouseover($self->{stub}, "Specify the base of the scan and image filenames.");
  $app->mouseover($self->{element}, "Specify the absorber element.");
  $app->mouseover($self->{stub}, "Specify the measured emission line.");
  $app->mouseover($self->{div10}, "Divide emission energies by 10.");
  #$app->mouseover($self->{scale24}, "Scale oversized images by 1/2^24.");

  # my $icon = File::Spec->catfile(dirname($INC{"Demeter/UI/Metis.pm"}), 'Metis', 'share', "metis_logo.png");
  # my $logo = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);
  # $gbs -> Add(Wx::StaticText->new($self, -1, q{ }, wxDefaultPosition, [50,-1]),
  # 	      Wx::GBPosition->new(0,6));
  # $gbs -> Add(Wx::StaticBitmap->new($self, -1, $logo, wxDefaultPosition, [100,100]),
  # 	      Wx::GBPosition->new(0,7), Wx::GBSpan->new(4,1));


  ## ------ scan folder ----------------------------------------
  my $gbs = Wx::GridBagSizer->new( 5,5 );
  $vbox ->  Add($gbs, 0, wxGROW|wxALL, 0);

  my $scanfolder = $app->{base}->scanfolder || q{};
  #$self->{scan_label} = Wx::StaticText -> new($self, -1, "Scan folder");
  $self->{scan} = Wx::Button->new($self, -1, "Pick &scan folder", wxDefaultPosition, [140,-1]);
  $self->{scan_dir} = Wx::TextCtrl -> new($self, -1, $scanfolder, wxDefaultPosition, [300,-1], wxTE_READONLY);
  $app->mouseover($self->{scan}, "Select the location of the scan files.");
  #$hbox->Add($self->{scan_label}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $gbs->Add($self->{scan}, Wx::GBPosition->new(0,0));
  $gbs->Add($self->{scan_dir}, Wx::GBPosition->new(0,1));
  EVT_BUTTON($self, $self->{scan}, sub{SelectFolder(@_, $app, 'scan')});

  #$self->{scan} = Wx::DirPickerCtrl->new($self, -1, q{}, "Image folder", wxDefaultPosition, [500,-1],
  #					 wxDIRP_DIR_MUST_EXIST|wxDIRP_CHANGE_DIR|wxDIRP_USE_TEXTCTRL);
  #$self->{scan}->SetPath($scanfolder);
  #EVT_DIRPICKER_CHANGED($self,$self->{scan},sub{OnDirChanging(@_, $app)});

  ## ------ images folder ----------------------------------------
  my $tifffolder = $app->{base}->tifffolder || cwd;
  $self->{image} = Wx::Button->new($self, -1, "Pick &image folder", wxDefaultPosition, [140,-1]);
  $self->{image_dir} = Wx::TextCtrl -> new($self, -1, $tifffolder, wxDefaultPosition, [300,-1], wxTE_READONLY);
  $gbs -> Add($self->{image},   Wx::GBPosition->new(1,0));
  $gbs->Add($self->{image_dir}, Wx::GBPosition->new(1,1));
  $app->mouseover($self->{image}, "Select the location of the image files.");
  EVT_BUTTON($self, $self->{image}, sub{SelectFolder(@_, $app, 'image')});


  ## ------ templates -------------------------------------------
  $self->{scan_template_label} = Wx::StaticText -> new($self, -1, "Scan file template");
  $self->{scan_template} = Wx::TextCtrl -> new($self, -1, $app->{base}->scan_file_template, wxDefaultPosition, [150,-1]);
  $gbs->Add($self->{scan_template_label}, Wx::GBPosition->new(0,2));
  $gbs->Add($self->{scan_template}, Wx::GBPosition->new(0,3));

  $self->{elastic_template_label} = Wx::StaticText -> new($self, -1, "Elastic image template");
  $self->{elastic_template} = Wx::TextCtrl -> new($self, -1, $app->{base}->elastic_file_template, wxDefaultPosition, [150,-1]);
  $gbs->Add($self->{elastic_template_label}, Wx::GBPosition->new(1,2));
  $gbs->Add($self->{elastic_template}, Wx::GBPosition->new(1,3));

  $self->{image_template_label} = Wx::StaticText -> new($self, -1, "Scan image template");
  $self->{image_template} = Wx::TextCtrl -> new($self, -1, $app->{base}->image_file_template, wxDefaultPosition, [150,-1]);
  $gbs->Add($self->{image_template_label}, Wx::GBPosition->new(2,2));
  $gbs->Add($self->{image_template}, Wx::GBPosition->new(2,3));

  $app->mouseover($self->{scan_template},    'Elastic file template: %s=stub, %e=emission energy, %i=incident energy, %t=tiffcounter, %c energy counter');
  $app->mouseover($self->{elastic_template}, 'Image file template: %s=stub, %e=emission energy, %i=incident energy, %t=tiffcounter, %c energy counter');
  $app->mouseover($self->{image_template},   'Scan file template: %s=stub, %e=emission energy, %i=incident energy, %t=tiffcounter, %c energy counter');

  ## ------ fetch button ----------------------------------------
  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($hbox, 0, wxGROW|wxALL, 0);
  $self->{fetch} = Wx::Button->new($self, -1, "&Fetch file lists", wxDefaultPosition, [-1,-1]);
  $hbox -> Add($self->{fetch}, 1, wxALL|wxGROW, 5);
  $app->mouseover($self->{fetch}, "Fetch all image files and populate the file lists below.");
  EVT_BUTTON($self, $self->{fetch}, sub{fetch(@_, $app)});



  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my $elasticbox       = Wx::StaticBox->new($self, -1, "Elastic files", wxDefaultPosition, wxDefaultSize);
  my $elasticboxsizer  = Wx::StaticBoxSizer->new( $elasticbox, wxVERTICAL );

  $self->{elastic_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $elasticboxsizer -> Add($self->{elastic_list}, 1, wxGROW);
  $hbox -> Add($elasticboxsizer, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX_DCLICK($self, $self->{elastic_list}, sub{view(@_, $app, 'elastic')});
  $app->mouseover($self->{elastic_list}, "Double click to display an elastic image file.");

  my $imagebox       = Wx::StaticBox->new($self, -1, "Image files", wxDefaultPosition, wxDefaultSize);
  my $imageboxsizer  = Wx::StaticBoxSizer->new( $imagebox, wxVERTICAL );

  $self->{image_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $imageboxsizer -> Add($self->{image_list}, 1, wxGROW);
  $hbox -> Add($imageboxsizer, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX_DCLICK($self, $self->{image_list}, sub{view(@_, $app, 'image')});
  $app->mouseover($self->{image_list}, "Double click to display the image file for a data point.");

  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);

  if ($app->{tool} ne 'herfd') {
    $app->{base}->noscan(1);
    $app->{base}->scanfolder(q{});
    $self->{scan_dir}->SetValue(q{});
    $self->{$_}->Enable(0) foreach (qw(scan scan_dir scan_template scan_template_label));
  };
  
  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub fetch {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();

  $app->{base}->Reset;
  $app->{base}->noscan(1) if ($app->{tool} ne 'herfd');
  $app->{bla_of}->{aggregate}->Reset;
  ## clear out previous batch of Xray::BLA objects
  foreach my $b (keys %{$app->{bla_of}}) {
    next if $b eq 'aggregate';
    delete $app->{bla_of}->{$b};
  };

  # my $sft = $self->{scan_template}->GetValue;
  # my $eft = $self->{elastic_template}->GetValue;
  # my $ift = $self->{image_template}->GetValue;
  # $app->{base}->scan_file_template($sft);
  # $app->{base}->elastic_file_template($eft);
  # $app->{base}->image_file_template($ift);

  # my $stub           = $self->{stub}->GetValue;
  # my $scan_folder    = $self->{scan_dir}->GetValue;
  # my $image_folder   = $self->{image_dir}->GetValue;
  # $app->{base}->stub($stub);
  # $app->{base}->scanfolder($scan_folder);
  # $app->{base}->tifffolder($image_folder);
  # $app->{base}->div10($self->{div10}->GetValue);
  # #$app->{base}->tifscale(2**24) if $self->{scale24}->GetValue;
  # $app->{bla_of}->{aggregate}->stub($stub);
  # $app->{bla_of}->{aggregate}->scanfolder($scan_folder);
  # $app->{bla_of}->{aggregate}->tifffolder($image_folder);
  # $app->{bla_of}->{aggregate}->div10($self->{div10}->GetValue);


  $app->{base} -> clear_elastic_energies;
  $self->{elastic_list}->Clear;
  $self->{image_list}->Clear;
  $app->set_parameters;

  if (not $app->{base}->noscan) {
    if (not -e File::Spec->catfile($app->{base}->scanfolder, $app->{base}->file_template($app->{base}->scan_file_template))) {
      $app->{main}->status(sprintf("Scan file for %s not found in %s.", $app->{base}->stub, $app->{base}->scanfolder) , 'alert');
      return;
    };
  };

#  if (($stub eq $app->{base}->stub) and ($self->{elastic_list}->GetCount)) {
#    $app->{main}->status("Stub $stub hasn't changed.");
#    return;
#  };

  if (not $app->{base}->noscan) {
    my $sf = $app->{base} -> check_scan;
    if (not $sf->is_ok) {
      $app->{main}->status($sf->message, 'alert');
      return;
    };
  };

  my ($us, $stub, $image_folder) = (q{_}, $app->{base}->stub, $app->{base}->tifffolder);
  opendir(my $E, $image_folder);
  my @elastic_list = sort {$a cmp $b} grep {$_ =~ m{\A$stub$us}} (grep {$_ =~ m{elastic}} (grep {$_ =~ m{.tif\z}} readdir $E));
  closedir $E;
  #print join($/, @elastic_list), $/;
  if ($#elastic_list == -1) {
    $app->{main}->status("No elastic files for $stub found in $image_folder.", 'alert');
    return;
  };
  $self->{elastic_list}->InsertItems(\@elastic_list,0);

  opendir(my $I, $image_folder);
  my @image_list = sort {$a cmp $b} grep {$_ =~ m{\A$stub$us}} (grep {$_ !~ m{elastic}} (grep {$_ =~ m{.tif\z}} readdir $I));
  closedir $I;
  #print join($/, @image_list), $/;
  if ($#image_list == -1) {
    $app->{main}->status("No image files for $stub found in $image_folder.", 'alert');
    return;
  };
  $self->{image_list}->InsertItems(\@image_list,0);

  foreach my $e (@elastic_list) {
    $app->{base}->push_elastic_file_list($e);
    ($e =~ m{elastic_(\d+)_}) and
      $app->{base}->push_elastic_energies($1);
    $app->{bla_of}->{$1} = $app->{base}->clone;
    $app->{bla_of}->{$1}->elastic_file($e);
    $app->{bla_of}->{$1}->energy($1);
    my $ret = $app->{bla_of}->{$1}->check($e);
    if ($ret->status == 0) {
      $app->{main}->status($ret->message, 'alert');
      return;
    };
  };
  $app->{bla_of}->{aggregate}->elastic_energies($app->{base}->elastic_energies);
  $app->{bla_of}->{aggregate}->elastic_file_list($app->{base}->elastic_file_list);

  my ($el, $li) = $app->{base}->guess_element_and_line;

  my $e = Xray::Absorption -> get_energy($el, $li);
  my @list = ();
  foreach my $l (@Xray::BLA::line_list) {
    if (abs($l->[2] - $e) < 30) {
      push @list, join(" ", ucfirst($l->[0]), ucfirst($l->[1]), $l->[2]);
    };
  };
  if ($#list) {
    my $scd = Wx::SingleChoiceDialog->new($self, "Which line is this?", "Choose line", \@list);
    if ($scd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Using $el $li.");
    } else {
      my $choice = $scd->GetStringSelection;
      my $en;
      ($el, $li, $en) = split(" ", $choice);
      $app->{main}->status("Using $el $li.");
    };
  };

  $self->{element}->SetSelection(get_Z($el)-1);
  $self->{line}->SetStringSelection($li);
  $app->set_parameters;

  $app->{Mask}->{stub} -> SetLabel("Stub is \"$stub\"");
  $app->{Mask}->{energy} -> Enable(1);
  $app->{Mask}->{rangemin} -> Enable(1);
  $app->{Mask}->{rangemax} -> Enable(1);
  $app->{Mask}->{energy} -> Clear;
  $app->{Mask}->{energy} -> Append($_) foreach @{$app->{base}->elastic_energies};
  my $start = ($app->{tool} eq 'herfd') ? int(($#{$app->{base}->elastic_energies}+1)/2) : 0;
  $app->{Mask}->{energy} -> SetSelection($start);
  $app->{Mask}->restore($app);
  $app->{Data}->restore;

  $app->{main}->status("Found elastic and image files for $stub");
  undef $busy;
};

sub view {
  my ($self, $event, $app, $which) = @_;
  my $stub   = $self->{stub}->GetValue;
  my $folder = $self->{image_dir}->GetValue;
  my $img    = $self->{$which."_list"} -> GetStringSelection;
  my $file   = File::Spec->catfile($folder, $img);

  if ($which eq 'image') {
    $app->{base}->plot_energy_point($file);
    $app->{main}->status("Plotted energy point $file");
    return;
  };

  my $spectrum;
  ($img =~ m{elastic_(\d+)_}) and
    $spectrum = $app->{bla_of}->{$1};

  $spectrum -> tifffolder($folder);
  $spectrum -> stub($stub);
  if ($file =~ m{elastic_(\d+)_}) {
    $spectrum -> energy($1);
  } else {
    $app->{main}->status("Can't figure out energy...", 'alert');
    return;
  };

  my $cbm = int($spectrum->elastic_image->max);
  if ($cbm < 1) {
    $cbm = 1;
  } elsif ($cbm > $spectrum->bad_pixel_value/$spectrum->imagescale) {
    $cbm = $spectrum->bad_pixel_value/$spectrum->imagescale;
  };
  $spectrum->cbmax($cbm);# if $step =~ m{social};
  $spectrum->plot_mask;
  $app->{main}->status("Plotted ".$spectrum->elastic_file);

};


sub SelectFolder {
  my ($self, $event, $app, $which) = @_;
  my $current = ($which eq 'scan') ? $self->{scan_dir}->GetValue : $self->{image_dir}->GetValue;
  my $dd = Wx::DirDialog->new( $app->{main}, "Location of $which folder",
                               $current||cwd, wxDD_DEFAULT_STYLE|wxDD_CHANGE_DIR);
  if ($dd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Setting $which folder canceled.");
    return;
  };
  my $dir  = $dd->GetPath;
  if ($which eq 'scan') {
    $self->{scan_dir}->SetValue($dir);
    $app->{base}->scanfolder($dir);
  } else {
    $self->{image_dir}->SetValue($dir);
    $app->{base}->tifffolder($dir);
  };
};

sub OnDirChanging {
  #print join("|", @_);
  # my $tc;
  # foreach my $c ($self->{scan}->GetChildren) {
  #   $tc = $c if ref($c) =~ m{TextCtrl};
  # };
  # $tc->SetSize(400,-1);
  # print join("|", $tc -> GetMinSize->GetWidth, $tc -> GetMaxSize->GetWidth, $tc->GetSizeWH);
  # $self->{scan}->Update;
  1;
};

1;


=head1 NAME

Demeter::UI::Metis::Files - Metis' file organization tool

=head1 VERSION

This documentation refers to Xray::BLA version 2.

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

Copyright (c) 2006-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

