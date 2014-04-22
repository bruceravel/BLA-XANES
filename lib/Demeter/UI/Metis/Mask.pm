package Demeter::UI::Metis::Mask;

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_COMBOBOX EVT_BUTTON EVT_RADIOBOX EVT_CHECKBOX);

sub new {
  my ($class, $page, $app) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($vbox, 2, wxGROW|wxALL);

  $self->{title} = Wx::StaticText->new($self, -1, "Create mask");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox ->  Add($self->{title}, 0, wxGROW|wxALL, 5);


  my $sbox = Wx::BoxSizer->new( wxVERTICAL );

  my $stepsbox       = Wx::StaticBox->new($self, -1, 'Mask building steps', wxDefaultPosition, wxDefaultSize);
  my $stepsboxsizer  = Wx::StaticBoxSizer->new( $stepsbox, wxVERTICAL );

  $self->{steps_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $stepsboxsizer -> Add($self->{steps_list}, 1, wxGROW);
  $hbox -> Add($sbox, 1, wxGROW|wxALL, 5);
  $sbox -> Add($stepsboxsizer, 1, wxGROW|wxALL, 5);

  $self->{undostep} = Wx::Button->new($self, -1, 'Undo last step');
  $sbox -> Add($self->{undostep}, 0, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  EVT_BUTTON($self, $self->{undostep}, sub{undo_last_step(@_, $app)});
  $self->{savesteps} = Wx::Button->new($self, -1, 'Save steps');
  $sbox -> Add($self->{savesteps}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  EVT_BUTTON($self, $self->{savesteps}, sub{save_steps(@_, $app)});


  $self->{stub} = Wx::StaticText->new($self, -1, 'Stub is <undefined>');
  $vbox ->  Add($self->{stub}, 0, wxGROW|wxALL, 5);

  my $ebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($ebox, 0, wxGROW|wxALL, 5);

  $self->{rbox} = Wx::RadioBox->new($self, -1, 'Mask type', wxDefaultPosition, wxDefaultSize,
				    ['Single energy', 'Aggregate'], 1, wxRA_SPECIFY_COLS);
  $ebox->Add($self->{rbox}, 0, wxALL, 5);
  EVT_RADIOBOX($self, $self->{rbox}, sub{MaskType(@_, $app)});

  $self->{energylabel} = Wx::StaticText->new($self, -1, "Emission energy");
  $self->{energy} = Wx::ComboBox->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize, [75,-1], wxCB_READONLY);
  $ebox->Add($self->{energylabel}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $ebox->Add($self->{energy}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  EVT_COMBOBOX($self, $self->{energy}, sub{SelectEnergy(@_, $app)});
  $app->mouseover($self->{energy}, "Select the emission energy at which to prepare a mask.");

  $vbox ->  Add(1, 1, 1);


  my $buttonwidth = 150;
  my $gbs = Wx::GridBagSizer->new( 5,5 );
  $vbox ->  Add($gbs, 0, wxGROW|wxALL, 5);

  my $row = 0;

  $self->{do_bad}    = Wx::Button->new($self, -1, "&Bad/weak step", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $self->{badlabel}  = Wx::StaticText->new($self, -1, 'Bad value:');
  $self->{badvalue}  = Wx::SpinCtrl->new($self, -1, $app->{base}->bad_pixel_value, wxDefaultPosition, [70,-1], wxSP_ARROW_KEYS, 1, 10000);
  $self->{weaklabel} = Wx::StaticText->new($self, -1, 'Weak value:');
  $self->{weakvalue} = Wx::SpinCtrl->new($self, -1, $app->{base}->weak_pixel_value, wxDefaultPosition, [70,-1], wxSP_ARROW_KEYS, 0, 1000);
  $gbs ->Add($self->{do_bad},    Wx::GBPosition->new($row,0));
  $gbs ->Add($self->{badlabel},  Wx::GBPosition->new($row,1));
  $gbs ->Add($self->{badvalue},  Wx::GBPosition->new($row,2));
  $gbs ->Add($self->{weaklabel}, Wx::GBPosition->new($row,3));
  $gbs ->Add($self->{weakvalue}, Wx::GBPosition->new($row,4));
  $app->mouseover($self->{do_bad},    "Remove bad pixels weak pixels from the image.");
  $app->mouseover($self->{badvalue},  "Pixels above this value are considered bad.");
  $app->mouseover($self->{weakvalue}, "Pixels below this value are considered weak.");

  ++$row;
  $self->{do_areal}   = Wx::Button->new($self, -1, "&Areal step", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $self->{arealtype}  = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize,
					[qw(mean median)]);
  $self->{areallabel} = Wx::StaticText->new($self, -1, 'Radius:');
  $self->{arealvalue} = Wx::SpinCtrl->new($self, -1, $app->{base}->radius, wxDefaultPosition, [70,-1], wxSP_ARROW_KEYS, 1, 10);
  $gbs ->Add($self->{do_areal},   Wx::GBPosition->new($row,0));
  $gbs ->Add($self->{arealtype},  Wx::GBPosition->new($row,1));
  $gbs ->Add($self->{areallabel}, Wx::GBPosition->new($row,2));
  $gbs ->Add($self->{arealvalue}, Wx::GBPosition->new($row,3));
  $self->{arealtype}->SetSelection(0);
  $app->mouseover($self->{do_areal},   "Set each pixel to the average value of its neighbors within some radius.");
  $app->mouseover($self->{arealtype},  "Do the areal averaging as a mean or a median of surrounding pixels.  (Median is currently not implemented.)");
  $app->mouseover($self->{arealvalue}, "The \"radius\" of the averaging, a value of 1 uses a 3x3 square, 2 uses a 5x5 square.");

  ++$row;
  $self->{do_lonely} = Wx::Button->new($self, -1, "&Lonely pixels step", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $self->{lonelylabel}  = Wx::StaticText->new($self, -1, 'Lonely value:');
  $self->{lonelyvalue}  = Wx::SpinCtrl->new($self, -1, $app->{base}->lonely_pixel_value, wxDefaultPosition, [70,-1], wxSP_ARROW_KEYS, 1, 8);
  $gbs ->Add($self->{do_lonely},   Wx::GBPosition->new($row,0));
  $gbs ->Add($self->{lonelylabel}, Wx::GBPosition->new($row,1));
  $gbs ->Add($self->{lonelyvalue}, Wx::GBPosition->new($row,2));
  $app->mouseover($self->{do_lonely},   "Remove \"lonely\" pixels -- lit pixels surrounded by too many unlit pixels.");
  $app->mouseover($self->{lonelyvalue}, "A lit pixel is lonely and will be removed if less than or equal to this number of neighbors are unlit.");

  ++$row;
  $self->{do_social} = Wx::Button->new($self, -1, "&Social pixels step", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $self->{sociallabel}  = Wx::StaticText->new($self, -1, 'Social value:');
  $self->{socialvalue}  = Wx::SpinCtrl->new($self, -1, $app->{base}->social_pixel_value, wxDefaultPosition, [70,-1], wxSP_ARROW_KEYS, 1, 8);
  $self->{socialvertical} = Wx::CheckBox->new($self, -1, '&Vertical');
  $gbs ->Add($self->{do_social},   Wx::GBPosition->new($row,0));
  $gbs ->Add($self->{sociallabel}, Wx::GBPosition->new($row,1));
  $gbs ->Add($self->{socialvalue}, Wx::GBPosition->new($row,2));
  $gbs ->Add($self->{socialvertical}, Wx::GBPosition->new($row,3));
  $app->mouseover($self->{do_social},   "Include \"social\" pixels -- unlit pixels surrounded by enough lit pixels.");
  $app->mouseover($self->{socialvalue}, "An unlit pixel is social and will be included if greater tan or equal to this number of neighbors are lit.");
  $app->mouseover($self->{socialvalue}, "Perform the social pixel step, but only considering pixels directly above and below.");

  ++$row;
  $self->{do_multiply} = Wx::Button->new($self, -1, "M&ultiply by", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $self->{multiplyvalue}  = Wx::SpinCtrl->new($self, -1, '5', wxDefaultPosition, [70,-1], wxSP_ARROW_KEYS, 2, 1000);
  $gbs ->Add($self->{do_multiply},   Wx::GBPosition->new($row,0));
  $gbs ->Add($self->{multiplyvalue}, Wx::GBPosition->new($row,1));
  $app->mouseover($self->{do_multiply},   "Scale the entire mask by an integer value.");

  ++$row;
  $self->{do_aggregate} = Wx::Button->new($self, -1, "Use a&ggregate", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $gbs ->Add($self->{do_aggregate},   Wx::GBPosition->new($row,0));
  $app->mouseover($self->{do_aggregate},   "Multiply the current mask by the aggregate mask.");

  #++$row;
  $self->{do_entire} = Wx::Button->new($self, -1, "Entire image", wxDefaultPosition, [$buttonwidth,-1], wxBU_EXACTFIT);
  $gbs ->Add($self->{do_entire},   Wx::GBPosition->new($row,3), Wx::GBSpan->new(1,2));
  $app->mouseover($self->{do_areal},   "Set every pixel in the mask to 1 and generate (not-so) HERFD from the entire image.");


  $vbox ->  Add(1, 1, 2);

  my $svbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox->Add($svbox, 0, wxGROW|wxALL, 0);
  $self->{do_andmask} = Wx::Button->new($self, -1, "Finish mask", wxDefaultPosition, wxDefaultSize);
  $svbox->Add($self->{do_andmask}, 1, wxGROW|wxLEFT|wxRIGHT, 5);
  $self->{savemask} = Wx::Button -> new($self, -1, 'Save mask');
  $svbox->Add($self->{savemask}, 1, wxGROW|wxLEFT|wxRIGHT, 5);
  $self->{animation} = Wx::Button -> new($self, -1, 'Save animation');
  $svbox->Add($self->{animation}, 1, wxGROW|wxLEFT|wxRIGHT, 5);
  EVT_BUTTON($self, $self->{savemask}, sub{savemask(@_, $app)});
  EVT_BUTTON($self, $self->{animation}, sub{animation(@_, $app)});
  $app->mouseover($self->{do_andmask}, "Explicitly convert current mask to an AND mask (i.e. with only 0 and 1 values).");
  $app->mouseover($self->{savemask}, "Write the current mask to an image file.");
  $app->mouseover($self->{animation}, "Save the mask processing steps as an animated gif.");


  $svbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox->Add($svbox, 0, wxGROW|wxALL, 0);
  $self->{replot} = Wx::Button -> new($self, -1, '&Replot');
  $svbox->Add($self->{replot}, 1, wxGROW|wxALL, 5);
  $self->{reset} = Wx::Button -> new($self, -1, 'Rese&t');
  $svbox->Add($self->{reset}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{replot}, sub{replot(@_, $app, 0)});
  EVT_BUTTON($self, $self->{reset}, sub{Reset(@_, $app)});
  $self->{replot}->Enable(0);
  $self->{reset}->Enable(0);
  $app->mouseover($self->{replot}, "Replot the mask after rerunning the processing steps.");
  $app->mouseover($self->{reset},  "Return to the measured elastic image and restart the mask.");

  #$vbox ->  Add(1, 1, 2);

  foreach my $k (qw(bad social lonely multiply areal entire aggregate andmask)) {
    EVT_BUTTON($self, $self->{"do_".$k}, sub{do_step(@_, $app, $k)});
  };
  EVT_CHECKBOX($self, $self->{socialvertical}, sub{$app->{base}->vertical($self->{socialvertical}->GetValue)});

  $self -> SetSizerAndFit( $hbox );

  foreach my $k (qw(do_bad badvalue badlabel weaklabel weakvalue
		    do_social sociallabel socialvalue socialvertical
		    do_lonely lonelylabel lonelyvalue
		    do_multiply multiplyvalue
		    do_areal arealtype areallabel arealvalue
		    do_entire do_aggregate do_andmask savemask animation
		    stub reset energylabel energy undostep savesteps rbox)) {
    $self->{$k} -> Enable(0);
  };

  return $self;
};

sub restore {
  my ($self, $app) = @_;
  $self->{steps_list}->Clear;
  foreach my $k (qw(do_bad badvalue badlabel weaklabel weakvalue rbox energylabel energy stub)) {
    $self->{$k}->Enable(1);
  };
  $self->SelectEnergy(q{}, $app, 1);
  $self->{rbox}->SetSelection(0);
};


sub MaskType {
  my ($self, $event, $app) = @_;
  my $type = $self->{rbox}->GetStringSelection;

  if ($type eq 'Single energy') {
    $self->{energy}->Enable(1);
    $self->{energylabel}->Enable(1);
    my $energy = $self->{energy}->GetStringSelection;
    if ($energy) {
      $self->plot($app, $app->{bla_of}->{$energy});
    };

  } elsif ($type eq 'Aggregate') {
    my $busy = Wx::BusyCursor->new();
    $self->{energy}->Enable(0);
    $self->{energylabel}->Enable(0);
    $app->{bla_of}->{aggregate}->aggregate;
    $app->{bla_of}->{aggregate}->plot_mask('aggregate');
    undef $busy;
  };

  foreach my $k (qw(do_bad badvalue badlabel weaklabel weakvalue)) {
    $self->{$k}->Enable(1);
  };
  foreach my $k (qw(do_social sociallabel socialvalue socialvertical
		    do_lonely lonelylabel lonelyvalue
		    do_multiply multiplyvalue
		    do_areal arealtype areallabel arealvalue
		    do_entire do_andmask do_aggregate undostep savemask animation)) {
    $self->{$k}->Enable(0);
  };
  $self->{steps_list}->Clear;
};


sub SelectEnergy {
  my ($self, $event, $app, $noplot) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  my $spectrum = $app->{bla_of}->{$energy};

  my $elastic_file;
  my $elastic_list = $app->{Files}->{elastic_list};
  foreach my $i (0 .. $elastic_list->GetCount-1) {
    if ($elastic_list->GetString($i) =~ m{$energy}) {
      $elastic_file = $elastic_list->GetString($i);
      last;
    };
  };

  my $ret = $spectrum->check($elastic_file);
  if ($ret->status == 0) {
     $app->{main}->status($ret->message, 'alert');
     return;
  };

  foreach my $k (qw(do_bad badvalue badlabel weaklabel weakvalue)) {
    $self->{$k}->Enable(1);
  };
  foreach my $k (qw(do_social sociallabel socialvalue socialvertical
		    do_lonely lonelylabel lonelyvalue
		    do_multiply multiplyvalue
		    do_areal arealtype areallabel arealvalue
		    do_entire do_andmask do_aggregate undostep savemask animation)) {
    $self->{$k}->Enable(0);
  };
  $self->{steps_list}->Clear;

  $self->plot($app, $spectrum) if not $noplot;
};

sub Reset {
  my ($self, $event, $app) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  my $key = ($self->{rbox}->GetStringSelection =~ m{Single}) ? $energy : 'aggregate';
  my $spectrum = $app->{bla_of}->{$key};

  $self->{steps_list}->Clear;
  $spectrum->energy($energy) if $energy;

  my $elastic_file;
  if ($spectrum->masktype eq 'single') {
    my $ret = $spectrum->check(basename($spectrum->elastic_file));
    if ($ret->status == 0) {
      $app->{main}->status($ret->message, 'alert');
      return;
    };
  };
  foreach my $k (qw(do_social sociallabel socialvalue socialvertical
		    do_lonely lonelylabel lonelyvalue
		    do_multiply multiplyvalue
		    do_areal arealtype areallabel arealvalue
		    do_entire do_andmask do_aggregate undostep savesteps savemask animation)) {
    $self->{$k}->Enable(0);
  };
  $app->{Data}->{stub}->SetLabel("Stub is <undefined>");
  $app->{Data}->{energylabel}->SetLabel("Current mask energy is <undefined>");
  $app->{Data}->{energy} = 0;
  foreach my $k (qw(stub energylabel herfd save_herfd mue)) {
    $app->{Data}->{$k}->Enable(0);
  };
  $self->{replot}->Enable(0);
  $self->{reset}->Enable(0);

  $spectrum->aggregate if ($spectrum->masktype eq 'aggregate');
  $self->plot($app, $spectrum);
};

sub do_step {
  my ($self, $event, $app, $which) = @_;
  my $busy = Wx::BusyCursor->new();
  my $energy = $self->{energy}->GetStringSelection;
  my $key = ($self->{rbox}->GetStringSelection =~ m{Single}) ? $energy : 'aggregate';
  if ($self->{rbox}->GetStringSelection =~ m{Single} and ($energy eq q{})) {
    $app->{main}->status("You haven't selected an emission energy.", 'alert');
    undef $busy;
    return;
  };
  my $spectrum = $app->{bla_of}->{$key};

  my %args = ();
  $args{write}    = q{};
  $args{verbose}  = 0;
  $args{unity}    = 0;
  $args{vertical} = $self->{socialvertical}->GetValue;

  my $success;
  if ($which eq 'bad') {
    $spectrum -> bad_pixel_value($self->{badvalue}->GetValue);
    $spectrum -> weak_pixel_value($self->{weakvalue}->GetValue);
    $success = $spectrum -> do_step('bad_pixels', %args);
    $self->{steps_list}->Append(sprintf("bad %d weak %d",
					$spectrum -> bad_pixel_value,
					$spectrum -> weak_pixel_value)) if $success;
    foreach my $k (qw(do_social sociallabel socialvalue socialvertical
		      do_lonely lonelylabel lonelyvalue
		      do_multiply multiplyvalue
		      do_areal arealtype areallabel arealvalue
		      do_entire do_andmask savemask
		      undostep savesteps)) { # animation
      $self->{$k}->Enable(1);
    };
    $self->{do_aggregate}->Enable(1) if ($spectrum->masktype eq 'single');
    $self->{savemask}->Enable(0) if ($spectrum->is_windows);
    $self->{replot}->Enable(1);
    $self->{reset}->Enable(1);
    $app->{Data}->{stub}->SetLabel("Stub is ".$spectrum->stub);
    $app->{Data}->{energylabel}->SetLabel("Current mask energy is ".$spectrum->energy);
    $app->{Data}->{energy} = $spectrum->energy;
    foreach my $k (qw(stub energylabel herfd mue xes showmasks incident incident_label rixs rshowmasks)) {
      $app->{Data}->{$k}->Enable(1);
    };
    $spectrum->get_incident_energies;
    my $rlist = $spectrum->incident_energies;
    $app->{base}->incident_energies($rlist);
    foreach my $key (keys %{$app->{bla_of}}) {
      $app->{bla_of}->{$key}->incident_energies($rlist);
    };
    $app->{Data}->{incident}->SetValue($rlist->[int($#{$rlist}/2)]);

  } elsif ($which eq 'social') {
    $spectrum -> social_pixel_value($self->{socialvalue}->GetValue);
    $spectrum -> vertical($self->{socialvertical}->GetValue);
    $success = $spectrum -> do_step('social_pixels', %args);
    my $vert_text = ($spectrum->vertical) ? q{ vertical} : q{};
    $self->{steps_list}->Append(sprintf("social %d%s",
					$spectrum -> social_pixel_value, $vert_text)) if $success;

  } elsif ($which eq 'lonely') {
    $spectrum -> lonely_pixel_value($self->{lonelyvalue}->GetValue);
    $success = $spectrum -> do_step('lonely_pixels', %args);
    $self->{steps_list}->Append(sprintf("lonely %d",
					$spectrum -> lonely_pixel_value)) if $success;

  } elsif ($which eq 'multiply') {
    $spectrum -> scalemask($self->{multiplyvalue}->GetValue);
    $success = $spectrum -> do_step('multiply', %args);
    $self->{steps_list}->Append(sprintf("multiply by %d",
					$spectrum -> scalemask)) if $success;

  } elsif ($which eq 'areal') {
    $spectrum -> operation($self->{arealtype}->GetStringSelection);
    $spectrum -> radius($self->{arealvalue}->GetValue);
    if ($spectrum -> operation eq 'median') {
      $app->{main}->status("Areal median is not available yet.", 'alert');
      undef $busy;
      return;
    };
    $success = $spectrum -> do_step('areal', %args);
    $self->{steps_list}->Append(sprintf("areal %s radius %d",
					$spectrum -> operation,
					$spectrum -> radius)) if $success;
  } elsif ($which eq 'entire') {
    $success = $spectrum -> do_step('entire_image', %args);
    $self->{steps_list}->Append("entire image") if $success;

  } elsif ($which eq 'aggregate') {
    if ($app->{bla_of}->{aggregate}->elastic_image->isnull) {
      $app->{main}->status("You haven't made an aggregate mask yet.", 'alert');
      undef $busy;
      return;
    };
    $app->{bla_of}->{aggregate} -> do_step('andmask', %args); # gotta be sure!
    $args{aggregate} = $app->{bla_of}->{aggregate};
    $success = $spectrum -> do_step('andaggregate', %args);
    $self->{steps_list}->Append("aggregate") if $success;

  } elsif ($which eq 'andmask') {
    $success = $spectrum -> do_step('andmask', %args);
    $self->{steps_list}->Append("andmask") if $success;
    $spectrum->clear_steps;
    foreach my $n (0 .. $self->{steps_list}->GetCount-1) {
      $spectrum->push_steps($self->{steps_list}->GetString($n));
    };

  };
  $spectrum->remove_bad_pixels;
  $self->plot($app, $spectrum);
  if ($success) {
    $app->{main}->status("Plotted result of $which step.");
  } else {
    $app->{main}->status("That action resulted in 0 illuminated pixels.  Returning to previous step.", 'alert');
  };
  undef $busy;

};


sub plot {
  my ($self, $app, $spectrum) = @_;
  my $cbm = int($spectrum->elastic_image->max);
  if ($cbm < 1) {
    $cbm = 1;
  } elsif ($cbm > $spectrum->bad_pixel_value/$spectrum->imagescale) {
    $cbm = $spectrum->bad_pixel_value/$spectrum->imagescale;
  };
  $spectrum->cbmax($cbm);
  if ($spectrum->masktype eq 'single') {
    $spectrum->plot_mask;
  } else {
    $spectrum->plot_mask('aggregate');
  };
  $app->{main}->status("Plotted ".$spectrum->elastic_file);
};


sub replot {
  my ($self, $event, $app, $animate) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  my $key = ($self->{rbox}->GetStringSelection =~ m{Single}) ? $energy : 'aggregate';
  my $spectrum = $app->{bla_of}->{$key};

  $animate ||= 0;
  my $busy = Wx::BusyCursor->new();
  $spectrum->energy($energy);

  my $elastic_file;
  my $elastic_list = $app->{Files}->{elastic_list};
  foreach my $i (0 .. $elastic_list->GetCount-1) {
    if ($elastic_list->GetString($i) =~ m{$energy}) {
      $elastic_file = $elastic_list->GetString($i);
      last;
    };
  };

  my $ret = $spectrum->check($elastic_file);
  if ($ret->status == 0) {
     $app->{main}->status($ret->message, 'alert');
     return;
  };
  $spectrum->clear_steps;
  foreach my $n (0 .. $self->{steps_list}->GetCount-1) {
    $spectrum->push_steps($self->{steps_list}->GetString($n));
  };
  if ($animate) {
    $spectrum->mask(animate=>1);
  } else {
    $spectrum->mask(elastic=>$elastic_file);
  };
  $self->plot($app, $spectrum);
  $app->{main}->status("Replotted mask for $energy.");
  undef $busy;
};

## Need to install NetPbm and Tiff tools
##   http://gnuwin32.sourceforge.net/packages/netpbm.htm
##   http://gnuwin32.sourceforge.net/packages/tiff.htm
## then need to make a copy of C:\GnuWin32\bin\ppm2tiff called C:\GnuWin32\bin\ppmtotiff
##
## Insanity!

sub savemask {
  my ($self, $event, $app) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  my $key = ($self->{rbox}->GetStringSelection =~ m{Single}) ? $energy : 'aggregate';
  my $spectrum = $app->{bla_of}->{$key};

  my $id = ($spectrum->masktype eq 'aggregate') ? 'aggregate' : $spectrum->energy;
  my $fname = $spectrum->stub . "_" . $id . ".";
  $fname .= ($spectrum->is_windows) ? 'tif' : $spectrum->outimage;
  my $extensions = ($spectrum->is_windows) ?
    "TIF (*.tif)|*.tif|All files (*)|*" :
      "TIF, GIF, and PNG (*.tif;*.gif*.png)|*.tif|TIF (*.tif)|*.tif|GIF (*.gif)|*.gif|PNG (*.png)|*.png|All files (*)|*";
  my $ag = ($spectrum->masktype eq 'aggregate') ? ' aggregate' : q{};
  my $fd = Wx::FileDialog->new( $app->{main}, "Save$ag mask image", cwd, $fname,
				$extensions,
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving mask image canceled.");
    return;
  };
  my $file = $fd->GetPath;
  my $args = ($spectrum->is_windows) ? {FORMAT=>'TIFF'} : {};
  $spectrum->elastic_image->wim($file, $args);
  if (($spectrum->is_windows) and ($file !~ m{tif\z})) {
    $app->{main}->status("TIFF is the only output format for Windows.  A TIFF file was written regardless of the filename.");
  } else {
    $app->{main}->status("Saved mask image to $file");
  };
};

sub animation {
  my ($self, $event, $app) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  my $key = ($self->{rbox}->GetStringSelection =~ m{Single}) ? $energy : 'aggregate';
  my $spectrum = $app->{bla_of}->{$key};

  my $fname = $spectrum->stub . "_" . $spectrum->energy . "." . $spectrum->outimage;
  my $fd = Wx::FileDialog->new( $app->{main}, "Save mask image", cwd, $fname,
				"GIF (*.gif)|*.gif|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving animation canceled.");
    return;
  };
  my $file = $fd->GetPath;
  $self->replot($event, $app, 1);
};

sub undo_last_step {
  my ($self, $event, $app) = @_;
  my $last = $self->{steps_list}->GetCount;
  $self->{steps_list}->Delete($last-1);
  if ($last == 1) {
    $self->Reset($event, $app);
  } else {
    $self->replot($event, $app);
  };

};

sub save_steps {
  my ($self, $event, $app) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  my $key = ($self->{rbox}->GetStringSelection =~ m{Single}) ? $energy : 'aggregate';
  my $spectrum = $app->{bla_of}->{$key};

  my $fname = $spectrum->stub . ".ini";
  my $fd = Wx::FileDialog->new( $app->{main}, "Save ini file", cwd, $fname,
				"INI (*.ini)|*.ini|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving ini file canceled.");
    return;
  };
  my $file = $fd->GetPath;

  my $text = "[measure]\n";
  $text .= 'emission           = ' . join(" ", @{$spectrum->elastic_energies}) . "\n";
  foreach my $k (qw(scanfolder tifffolder element line tiffcounter energycounterwidth
		    imagescale outimage)) {
    $text .= sprintf("%-18s = %s\n", $k, $spectrum->$k);
  };
  $text .= "outfolder          = " . $fd->GetDirectory . "\n";
  $text .= "\n[steps]\nsteps <<END\n";
  foreach my $n (0 .. $self->{steps_list}->GetCount-1) {
    $text .= $self->{steps_list}->GetString($n) . "\n";
  };
  $text .= "END\n";

  open(my $INI, '>', $file);
  print $INI $text;
  close $INI;
  $app->{main}->status("Saved ini file to $file.");
};

1;


=head1 NAME

Demeter::UI::Metis::Mask - Metis' mask creation tool

=head1 VERSION

This documentation refers to Xray::BLA version 2.

=head1 DESCRIPTION

Metis is a graphical interface the Xray::BLA package for processing
data from an energy dispersive bent Laue analyzer spectrometer in
which the signal is dispersed onto the face of a Pilatus camera.

The mask tool is used to process an elastic image into a mask for
processing a sequence of camera exposures into a HERFD spectrum.

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

