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

  $self->{add} = Wx::Button->new($self, -1, "&Refresh images", wxDefaultPosition, [-1,-1]);
  $hbox -> Add($self->{add}, 0, wxALL, 5);
  $app->mouseover($self->{add}, "Add newly arrived image files.");
  EVT_BUTTON($self, $self->{add}, sub{more(@_, $app)});


  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my $elasticbox       = Wx::StaticBox->new($self, -1, "Elastic files", wxDefaultPosition, wxDefaultSize);
  my $elasticboxsizer  = Wx::StaticBoxSizer->new( $elasticbox, wxVERTICAL );

  $self->{elastic_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $elasticboxsizer -> Add($self->{elastic_list}, 1, wxGROW|wxALL, 4);
  $hbox -> Add($elasticboxsizer, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX_DCLICK($self, $self->{elastic_list}, sub{view(@_, $app, 'elastic')});
  $app->mouseover($self->{elastic_list}, "Double click to display an elastic image file.");

  my $imagebox       = Wx::StaticBox->new($self, -1, "Image files", wxDefaultPosition, wxDefaultSize);
  my $imageboxsizer  = Wx::StaticBoxSizer->new( $imagebox, wxVERTICAL );

  $self->{image_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $imageboxsizer -> Add($self->{image_list}, 1, wxGROW|wxALL, 4);
  $hbox -> Add($imageboxsizer, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX_DCLICK($self, $self->{image_list}, sub{view(@_, $app, 'image')});
  $app->mouseover($self->{image_list}, "Double click to display the image file for a data point.");

  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);

  if ($app->{tool} eq 'xes') {
    $app->{base}->noscan(1);
    $app->{base}->scanfolder(q{});
    $self->{scan_dir}->SetValue(q{});
    $self->{$_}->Enable(0) foreach (qw(scan scan_dir scan_template scan_template_label));
  } elsif ($app->{tool} eq 'rxes') {
    $app->{base}->noscan(0);
    $app->{base}->image_file_template(q{});
    $self->{image_template}->SetValue(q{});
    $self->{$_}->Enable(0) foreach (qw(image_template image_template_label));
  } elsif ($app->{tool} eq 'mask') {
    $app->{base}->noscan(1);
    $app->{base}->scanfolder(q{});
    $self->{scan_dir}->SetValue(q{});
    $self->{$_}->Enable(0) foreach (qw(scan scan_dir scan_template scan_template_label
				       elastic_template elastic_template_label
				       image_template image_template_label image image_dir
				       div10 stub stub_label element element_label line line_label add));
    $self->{fetch}->SetLabel("Import image");
    EVT_BUTTON($self, $self->{fetch}, sub{single(@_, $app)});
  };

  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub fetch {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();

  $app->{base}->Reset;
  $app->{base}->noscan(1) if ($app->{tool} eq 'xes');
  $app->{bla_of}->{aggregate}->Reset;
  ## clear out previous batch of Xray::BLA objects
  foreach my $b (keys %{$app->{bla_of}}) {
    next if $b eq 'aggregate';
    delete $app->{bla_of}->{$b};
  };

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

  if (not $app->{base}->noscan) {
    my $sf = $app->{base} -> check_scan;
    if (not $sf->is_ok) {
      $app->{main}->status($sf->message, 'alert');
      return;
    };
  };

  my $elastic_re = $app->{base}->file_template($self->{elastic_template}->GetValue, {re=>1});
  my ($us, $stub, $image_folder) = (q{_}, $app->{base}->stub, $app->{base}->tifffolder);
  opendir(my $E, $image_folder);
  my @elastic_list = sort {$a cmp $b} grep {$_ =~ m{$elastic_re}} readdir $E;
  closedir $E;
  if ($#elastic_list == -1) {
    $app->{main}->status("No elastic files for $elastic_re found in $image_folder.", 'alert');
    return;
  };
  $self->{elastic_list}->InsertItems(\@elastic_list,0);

  my @image_list = ();
  if ($self->{image_template}->GetValue !~ m{\A\s*\z}) {
    my $image_re   = $app->{base}->file_template($self->{image_template}->GetValue, {re=>1});
    opendir(my $I, $image_folder);
    @image_list = sort {$a cmp $b} grep {$_ =~ m{$image_re}} readdir $I;
    closedir $I;
    if ($#image_list == -1) {
      $app->{main}->status("No image files for $image_re found in $image_folder.", 'alert');
      return;
    };
    $self->{image_list}->InsertItems(\@image_list,0);
  };

  $app->{main}->status("Setting up elastic files.  This may take some time....");
  my $count = 0;
  foreach my $e (@elastic_list) {
    ++$count;
    $app->{main}->status(sprintf("Preparing %s (%d of %d)", $e, $count, $#elastic_list),
			 'wait|nobuffer') if (not $count%5);
    $app->{base}->push_elastic_file_list($e);
    if ($e =~ m{$elastic_re}) {
      my $this = $+{e} || $+{c};

      $app->{base}->push_elastic_energies($this);
      $app->{bla_of}->{$this} = $app->{base}->clone;
      $app->{bla_of}->{$this}->elastic_file($this);
      $app->{bla_of}->{$this}->energy($this);
      my $ret = $app->{bla_of}->{$this}->check($e);
      if ($ret->status == 0) {
	$app->{main}->status($ret->message, 'alert');
	return;
      };
    };
  };
  $app->{bla_of}->{aggregate}->elastic_energies($app->{base}->elastic_energies);
  $app->{bla_of}->{aggregate}->elastic_file_list($app->{base}->elastic_file_list);

  $app->{base}->get_incident_energies;
  my $rlist = $app->{base}->incident_energies;
  $app->{base}->incident_energies($rlist);
  #$app->{base}->elastic_energies($rlist) if ($app->{tool} eq 'rxes');
  foreach my $key (keys %{$app->{bla_of}}) {
    $app->{bla_of}->{$key}->incident_energies($rlist);
    #$app->{bla_of}->{$key}->elastic_energies($rlist) if ($app->{tool} eq 'rxes');
  };


  $app->{Data}->{incident}->Clear;
  if ($app->{tool} eq 'herfd') {
    foreach my $en (@$rlist) {
      $app->{Data}->{incident}->Append($en);
    };
    $app->{Data}->{incident}->SetSelection(int($#{$rlist}/2));
  } else {
    foreach my $im (@image_list) {
      $app->{Data}->{incident}->Append($im);
    };
    $app->{Data}->{incident}->SetSelection(0);
  };

  if ($app->{tool} eq 'rxes') {
    $self->{element}->SetStringSelection('H');
    $self->{line}->SetStringSelection('Ka1');
    $self->{element}->Enable(0);
    $self->{line}->Enable(0);
  } else {
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
  };
  $app->set_parameters;

  $app->{Mask}->{stub} -> SetLabel("Stub is \"$stub\"");
  $app->{Mask}->{$_} -> Enable(1) foreach (qw(steps_list spots_list pluck restoresteps energy rangemin rangemax));
  $app->{Mask}->{energy} -> Clear;
  $app->{Mask}->{energy} -> Append($_) foreach @{$app->{base}->elastic_energies};
  my $start = ($app->{tool} eq 'herfd') ? int(($#{$app->{base}->elastic_energies}+1)/2) : 0;
  $app->{Mask}->{energy} -> SetSelection($start);
  $app->{Mask}->restore($app);
  $app->{Data}->restore;

  $app->{main}->status("Found elastic and image files for $stub");
  undef $busy;
};

sub more {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $stub = $app->{base}->stub;
  my $image_folder = $app->{base}->tifffolder;

  $self->{image_list}->Clear;
  my @image_list = ();
  if ($self->{image_template}->GetValue !~ m{\A\s*\z}) {
    my $image_re   = $app->{base}->file_template($self->{image_template}->GetValue, {re=>1});
    opendir(my $I, $image_folder);
    @image_list = sort {$a cmp $b} grep {$_ =~ m{$image_re}} readdir $I;
    closedir $I;
    if ($#image_list == -1) {
      $app->{main}->status("No image files for $image_re found in $image_folder.", 'alert');
      return;
    };
    $self->{image_list}->InsertItems(\@image_list,0);
  };

  $app->{main}->status("Refreshed image file list for $stub");
  undef $busy;
};


sub single {
  my ($self, $event, $app) = @_;
  my $fd = Wx::FileDialog->new($::app->{main}, "Import a Pilatus image", cwd, q{},
			       "TIF (*.tif)|*.tif|All files (*)|*",
			       wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR,
			       wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Importing image canceled.");
    return;
  };

  $self->{elastic_list}->Clear;

  my $dir = $fd->GetDirectory;
  my $file = $fd->GetFilename;
  $self->{image_dir}->Enable(1);
  $self->{image_dir}->SetValue($dir);
  $app->{base}->tifffolder($dir);
  $self->{image_dir}->Enable(0);
  $self->{elastic_list}->InsertItems([$file],0);

  $app->{base}->push_elastic_file_list($file);
  #if ($e =~ m{$elastic_re}) {
  #  my $this = $+{e} || $+{c};

  $app->{base}->push_elastic_energies('0001');
  $app->{bla_of}->{'0001'} = $app->{base}->clone;
  $app->{bla_of}->{'0001'}->elastic_file($fd->GetPath);
  $app->{bla_of}->{'0001'}->energy('0001');
  #my $ret = $app->{bla_of}->{$this}->check($e);

  $app->{base}->push_elastic_energies('0001');

  $app->{Mask}->{$_} -> Enable(1) foreach (qw(steps_list spots_list pluck restoresteps energy rangemin rangemax));
  $app->{Mask}->{energy} -> Clear;
  $app->{Mask}->{energy} -> Append('0001');
  $app->{Mask}->{energy} -> SetStringSelection('0001');
  $app->{Mask}->restore($app);

  $app->{book}->SetSelection(1);

};

sub view {
  my ($self, $event, $app, $which) = @_;
  my $stub   = $self->{stub}->GetValue;
  my $folder = $self->{image_dir}->GetValue;
  my $img    = $self->{$which."_list"} -> GetStringSelection;
  my $file   = File::Spec->catfile($folder, $img);

  #  if ($which eq 'image') {
  $app->{base}->plot_energy_point($file);
  $app->{main}->status("Plotted energy point $file");
  return;
  #  };
}
  
#   my $elastic_re = $app->{base}->file_template($self->{elastic_template}->GetValue, {re=>1});
#   my $spectrum;
#   if ($img =~ m{$elastic_re}) {
#     my $this = $+{e} || $+{c};
#     $spectrum = $app->{bla_of}->{$this};
#   } else {
#     $app->{main}->status("Can't find the file you just clicked on...", 'error');
#   };

#   $spectrum -> tifffolder($folder);
#   $spectrum -> stub($stub);
#   if ($file =~ m{$elastic_re}) {
#     my $this = $+{e} || $+{c};
#     $spectrum -> energy($this);
#   } else {
#     $app->{main}->status("Can't figure out energy...", 'alert');
#     return;
#   };

#   my $cbm = int($spectrum->elastic_image->max);
#   if ($cbm < 1) {
#     $cbm = 1;
#   } elsif ($cbm > $spectrum->bad_pixel_value/$spectrum->imagescale) {
#     $cbm = $spectrum->bad_pixel_value/$spectrum->imagescale;
#   };
#   $spectrum->cbmax($cbm);# if $step =~ m{social};
#   $spectrum->plot_mask;
#   $app->{main}->{Lastplot}->put_text($PDL::Graphics::Gnuplot::last_plotcmd);
#   $app->{main}->status("Plotted ".$spectrum->elastic_file);

# };


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

