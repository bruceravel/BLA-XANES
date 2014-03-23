package Demeter::UI::Metis::Mask;

use strict;
use warnings;

use Cwd;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_COMBOBOX EVT_BUTTON);

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

  $self->{savesteps} = Wx::Button->new($self, -1, 'Save steps');
  $sbox -> Add($self->{savesteps}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  EVT_BUTTON($self, $self->{savesteps}, sub{save_steps(@_, $app)});


  $self->{stub} = Wx::StaticText->new($self, -1, 'Stub is <undefined>');
  $vbox ->  Add($self->{stub}, 0, wxGROW|wxALL, 5);

  my $ebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($ebox, 0, wxGROW|wxALL, 5);

  $self->{energylabel} = Wx::StaticText->new($self, -1, "Emission energy");
  $self->{energy} = Wx::ComboBox->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize, [], wxCB_READONLY);
  $ebox->Add($self->{energylabel}, 0, wxALL, 5);
  $ebox->Add($self->{energy}, 0, wxALL, 5);
  EVT_COMBOBOX($self, $self->{energy}, sub{SelectEnergy(@_, $app)});
  $app->mouseover($self->{energy}, "Select the emission energy at which to prepare a mask.");

  $vbox ->  Add(1, 1, 1);


  my $buttonwidth = 150;
  my $gbs = Wx::GridBagSizer->new( 5,5 );
  $vbox ->  Add($gbs, 0, wxGROW|wxALL, 5);

  $self->{do_bad}    = Wx::Button->new($self, -1, "&Bad/weak step", wxDefaultPosition, [$buttonwidth,-1]);
  $self->{badlabel}  = Wx::StaticText->new($self, -1, 'Bad value:');
  $self->{badvalue}  = Wx::TextCtrl->new($self, -1, $app->{spectrum}->bad_pixel_value);
  $self->{weaklabel} = Wx::StaticText->new($self, -1, 'Weak value:');
  $self->{weakvalue} = Wx::TextCtrl->new($self, -1, $app->{spectrum}->weak_pixel_value);
  $gbs ->Add($self->{do_bad},    Wx::GBPosition->new(0,0));
  $gbs ->Add($self->{badlabel},  Wx::GBPosition->new(0,1));
  $gbs ->Add($self->{badvalue},  Wx::GBPosition->new(0,2));
  $gbs ->Add($self->{weaklabel}, Wx::GBPosition->new(0,3));
  $gbs ->Add($self->{weakvalue}, Wx::GBPosition->new(0,4));
  $app->mouseover($self->{do_bad},    "Remove bad pixels weak pixels from the image.");
  $app->mouseover($self->{badvalue},  "Pixels above this value are considered bad.");
  $app->mouseover($self->{weakvalue}, "Pixels below this value are considered weak.");

  $self->{do_social} = Wx::Button->new($self, -1, "&Social pixels step", wxDefaultPosition, [$buttonwidth,-1]);
  $self->{sociallabel}  = Wx::StaticText->new($self, -1, 'Social value:');
  $self->{socialvalue}  = Wx::TextCtrl->new($self, -1, $app->{spectrum}->social_pixel_value);
  $self->{socialvertical} = Wx::CheckBox->new($self, -1, '&Vertical');
  $gbs ->Add($self->{do_social},   Wx::GBPosition->new(1,0));
  $gbs ->Add($self->{sociallabel}, Wx::GBPosition->new(1,1));
  $gbs ->Add($self->{socialvalue}, Wx::GBPosition->new(1,2));
  $gbs ->Add($self->{socialvertical}, Wx::GBPosition->new(1,3));
  $app->mouseover($self->{do_social},   "Include \"social\" pixels -- unlit pixels surrounded by enough lit pixels.");
  $app->mouseover($self->{socialvalue}, "The number of neighboring lit pixels marking an unlit pixel as social.");
  $app->mouseover($self->{socialvalue}, "Perform the social pixel step, but only considering pixels directly above and below.");

  $self->{do_lonely} = Wx::Button->new($self, -1, "&Lonely pixels step", wxDefaultPosition, [$buttonwidth,-1]);
  $self->{lonelylabel}  = Wx::StaticText->new($self, -1, 'Lonely value:');
  $self->{lonelyvalue}  = Wx::TextCtrl->new($self, -1, $app->{spectrum}->lonely_pixel_value);
  $gbs ->Add($self->{do_lonely},    Wx::GBPosition->new(2,0));
  $gbs ->Add($self->{lonelylabel}, Wx::GBPosition->new(2,1));
  $gbs ->Add($self->{lonelyvalue}, Wx::GBPosition->new(2,2));
  $app->mouseover($self->{do_lonely},   "Remove \"lonely\" pixels -- lit pixels surrounded by too many unlit pixels.");
  $app->mouseover($self->{lonelyvalue}, "The number of neighboring unlit pixels marking an lit pixel as lonely.");

  $self->{do_multiply} = Wx::Button->new($self, -1, "M&ultiply by", wxDefaultPosition, [$buttonwidth,-1]);
  $self->{multiplyvalue}  = Wx::SpinCtrl->new($self, -1, '5', wxDefaultPosition, wxDefaultSize, wxSP_ARROW_KEYS, 2, 1000);
  $gbs ->Add($self->{do_multiply},    Wx::GBPosition->new(3,0));
  $gbs ->Add($self->{multiplyvalue}, Wx::GBPosition->new(3,1));
  $app->mouseover($self->{do_multiply},   "Scale the entire mask by an integer value.");

  $self->{do_areal}   = Wx::Button->new($self, -1, "&Areal step", wxDefaultPosition, [$buttonwidth,-1]);
  $self->{arealtype}  = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize,
					[qw(mean median)]);
  $self->{areallabel} = Wx::StaticText->new($self, -1, 'Radius:');
  $self->{arealvalue} = Wx::TextCtrl->new($self, -1, $app->{spectrum}->radius);
  $gbs ->Add($self->{do_areal},   Wx::GBPosition->new(4,0));
  $gbs ->Add($self->{arealtype},  Wx::GBPosition->new(4,1));
  $gbs ->Add($self->{areallabel}, Wx::GBPosition->new(4,2));
  $gbs ->Add($self->{arealvalue}, Wx::GBPosition->new(4,3));
  $self->{arealtype}->SetSelection(0);
  $app->mouseover($self->{do_areal},   "Set each pixel to the average value of its neighbors within some radius.");
  $app->mouseover($self->{arealtype},  "Do the areal averaging as a mean or a median of surrounding pixels.  (Median is currently not implemented.)");
  $app->mouseover($self->{arealvalue}, "The \"radius\" of the averaging, a value of 1 uses a 3x3 square, 2 uses a 5x5 square.");

  foreach my $k (qw(bad social lonely multiply areal)) {
    EVT_BUTTON($self, $self->{"do_".$k}, sub{do_step(@_, $app, $k)});
  };

  $vbox ->  Add(1, 1, 2);

  $self->{replot} = Wx::Button -> new($self, -1, '&Replot');
  $vbox->Add($self->{replot}, 0, wxGROW|wxALL, 5);
  $self->{reset} = Wx::Button -> new($self, -1, 'Rese&t');
  $vbox->Add($self->{reset}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{replot}, sub{replot(@_, $app)});
  EVT_BUTTON($self, $self->{reset}, sub{Reset(@_, $app)});
  $self->{replot}->Enable(0);
  $self->{reset}->Enable(0);
  $app->mouseover($self->{replot}, "Replot the mask after rerunning the processing steps.");
  $app->mouseover($self->{reset},  "Return to the measured elastic image and restart the mask.");

  $vbox ->  Add(1, 1, 2);

  $self -> SetSizerAndFit( $hbox );

  foreach my $k (qw(do_bad badvalue badlabel weaklabel weakvalue
		    do_social sociallabel socialvalue socialvertical
		    do_lonely lonelylabel lonelyvalue
		    do_multiply multiplyvalue
		    do_areal arealtype areallabel arealvalue
		    stub reset energylabel energy savesteps)) {
    $self->{$k} -> Enable(0);
  };

  return $self;
};

sub SelectEnergy {
  my ($self, $event, $app) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  $app->{spectrum}->energy($energy);

  my $ret = $app->{spectrum}->check;
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
		    do_areal arealtype areallabel arealvalue)) {
    $self->{$k}->Enable(0);
  };
  $self->{steps_list}->Clear;

  $self->plot($app);
};

sub Reset {
  my ($self, $event, $app) = @_;
  $self->{steps_list}->Clear;
  my $energy = $self->{energy}->GetStringSelection;
  $app->{spectrum}->energy($energy);

  my $ret = $app->{spectrum}->check;
  if ($ret->status == 0) {
     $app->{main}->status($ret->message, 'alert');
     return;
  };
  foreach my $k (qw(do_social sociallabel socialvalue socialvertical
		    do_lonely lonelylabel lonelyvalue
		    do_multiply multiplyvalue
		    do_areal arealtype areallabel arealvalue
		    savesteps)) {
    $self->{$k}->Enable(0);
  };
  $app->{Data}->{stub}->SetLabel("Stub is <undefined>");
  $app->{Data}->{energy}->SetLabel("Current mask energy is <undefined>");
  foreach my $k (qw(stub energy herfd save_herfd)) {
    $app->{Data}->{$k}->Enable(0);
  };
  $self->{replot}->Enable(0);
  $self->{reset}->Enable(0);

  $self->plot($app);
};

sub do_step {
  my ($self, $event, $app, $which) = @_;
  my $energy = $self->{energy}->GetStringSelection;
  if ($energy eq q{}) {
    $app->{main}->status("You haven't selected an emission energy.", 'alert');
    return;
  };

  my %args = ();
  $args{write}   = q{};
  $args{verbose} = 0;
  $args{unity}   = 0;

  if ($which eq 'bad') {
    $app->{spectrum} -> bad_pixel_value($self->{badvalue}->GetValue);
    $app->{spectrum} -> weak_pixel_value($self->{weakvalue}->GetValue);
    $app->{spectrum} -> do_step('bad_pixels', %args);
    $self->{steps_list}->Append(sprintf("bad %d weak %d",
					$app->{spectrum} -> bad_pixel_value,
					$app->{spectrum} -> weak_pixel_value));
    foreach my $k (qw(do_social sociallabel socialvalue socialvertical
		      do_lonely lonelylabel lonelyvalue
		      do_multiply multiplyvalue
		      do_areal arealtype areallabel arealvalue
		      savesteps)) {
      $self->{$k}->Enable(1);
    };
    $self->{replot}->Enable(1);
    $self->{reset}->Enable(1);
    $app->{Data}->{stub}->SetLabel("Stub is ".$app->{spectrum}->stub);
    $app->{Data}->{energy}->SetLabel("Current mask energy is ".$app->{spectrum}->energy);
    foreach my $k (qw(stub energy herfd)) {
      $app->{Data}->{$k}->Enable(1);
    };

  } elsif ($which eq 'social') {
    $app->{spectrum} -> social_pixel_value($self->{socialvalue}->GetValue);
    $app->{spectrum} -> do_step('social_pixels', %args);
    $self->{steps_list}->Append(sprintf("social %d",
					$app->{spectrum} -> social_pixel_value));

  } elsif ($which eq 'lonely') {
    $app->{spectrum} -> lonely_pixel_value($self->{lonelyvalue}->GetValue);
    $app->{spectrum} -> do_step('lonely_pixels', %args);
    $self->{steps_list}->Append(sprintf("lonely %d",
					$app->{spectrum} -> lonely_pixel_value));

  } elsif ($which eq 'multiply') {
    $app->{spectrum} -> scalemask($self->{multiplyvalue}->GetValue);
    $app->{spectrum} -> do_step('multiply', %args);
    $self->{steps_list}->Append(sprintf("multiply by %d",
					$app->{spectrum} -> scalemask));

  } elsif ($which eq 'areal') {
    $app->{spectrum} -> operation($self->{arealtype}->GetStringSelection);
    $app->{spectrum} -> radius($self->{arealvalue}->GetValue);
    if ($app->{spectrum} -> operation eq 'median') {
      $app->{main}->status("Areal median is not available yet.", 'alert');
      return;
    };
    $app->{spectrum} -> do_step('areal', %args);
    $self->{steps_list}->Append(sprintf("areal %s radius %d",
					$app->{spectrum} -> operation,
					$app->{spectrum} -> radius));

  };
  $self->plot($app);
  $app->{main}->status("Plotted result of $which step.");

};


sub plot {
  my ($self, $app) = @_;
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


sub replot {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $energy = $self->{energy}->GetStringSelection;
  $app->{spectrum}->energy($energy);

  my $ret = $app->{spectrum}->check;
  if ($ret->status == 0) {
     $app->{main}->status($ret->message, 'alert');
     return;
  };
  $app->{spectrum}->clear_steps;
  foreach my $n (0 .. $self->{steps_list}->GetCount-1) {
    $app->{spectrum}->push_steps($self->{steps_list}->GetString($n));
  };
  $app->{spectrum}->mask;
  $self->plot($app);
  $app->{main}->status("Replotted mask for $energy.");
  undef $busy;
};

sub save_steps {
  my ($self, $event, $app) = @_;

  my $fname = $app->{spectrum}->stub . ".ini";
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
  $text .= 'emission = ' . join(" ", @{$app->{spectrum}->elastic_energies}) . "\n";
  foreach my $k (qw(scanfolder tifffolder element line)) {
    $text .= sprintf("%s = %s\n", $k, $app->{spectrum}->$k);
  };
  $text .= "outfolder = " . $fd->GetDirectory . "\n";
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
