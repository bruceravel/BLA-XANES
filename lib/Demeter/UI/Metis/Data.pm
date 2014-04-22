package Demeter::UI::Metis::Data;

use strict;
use warnings;

use Compress::Zlib;
use Cwd;
use File::Basename;
use File::Copy;
use File::Spec;
use List::Compare;
use List::Util qw(max);

use PDL::Graphics::Simple;
use PDL::Graphics::Gnuplot qw(gplot image plot3d);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw( EVT_BUTTON EVT_COMBOBOX );

use Demeter::UI::Wx::SpecialCharacters qw($MU);

sub new {
  my ($class, $page, $app) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{title} = Wx::StaticText->new($self, -1, "Process data");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox ->  Add($self->{title}, 0, wxGROW|wxALL, 5);

  $self->{stub} = Wx::StaticText->new($self, -1, 'Stub is <undefined>');
  $vbox -> Add($self->{stub}, 0, wxGROW);
  $self->{energylabel} = Wx::StaticText->new($self, -1, 'Current mask energy is <undefined>');
  $vbox -> Add($self->{energylabel}, 0, wxGROW);
  $self->{energy} = 0;
  $self->{xesout} = q{};

  $vbox->Add(1,30,0);

  my $button_width = 125;

  my $herfdbox       = Wx::StaticBox->new($self, -1, ' HERFD ', wxDefaultPosition, wxDefaultSize);
  my $herfdboxsizer  = Wx::StaticBoxSizer->new( $herfdbox, wxHORIZONTAL );
  $vbox -> Add($herfdboxsizer, 0, wxGROW|wxALL, 5);
  $self->{herfdbox} = $herfdbox;

  $self->{herfd} = Wx::Button->new($self, -1, 'Process &HERFD', wxDefaultPosition, [$button_width,-1]);
  $herfdboxsizer -> Add($self->{herfd}, 0, wxGROW|wxALL, 5);
  $self->{replot_herfd} = Wx::Button->new($self, -1, '&Replot HERFD', wxDefaultPosition, [$button_width,-1]);
  $herfdboxsizer -> Add($self->{replot_herfd}, 0, wxGROW|wxALL, 5);
  $self->{save_herfd} = Wx::Button->new($self, -1, '&Save HERFD data', wxDefaultPosition, [$button_width,-1]);
  $herfdboxsizer -> Add($self->{save_herfd}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{herfd},        sub{plot_herfd(@_, $app)});
  EVT_BUTTON($self, $self->{replot_herfd}, sub{replot_herfd(@_, $app)});
  EVT_BUTTON($self, $self->{save_herfd},   sub{save_herfd(@_, $app)});
  $app->mouseover($self->{herfd}, "Process HERFD data using the current mask.");
  $app->mouseover($self->{replot_herfd}, "Replot the last HERFD spectrum.");
  $app->mouseover($self->{save_herfd},   "Save the last HERFD data to a column data file.");

  my $hfbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $herfdboxsizer -> Add($hfbox, 0, wxGROW|wxALL, 0);
  $self->{mue} = Wx::CheckBox->new($self, -1, "Include conventional $MU(E) in plot");
  $hfbox -> Add($self->{mue}, 0, wxGROW|wxALL, 0);
  $self->{mue}->SetValue(0);

  $vbox->Add(1,30,0);

  my $xesbox       = Wx::StaticBox->new($self, -1, ' XES ', wxDefaultPosition, wxDefaultSize);
  my $xesboxsizer  = Wx::StaticBoxSizer->new( $xesbox, wxVERTICAL );
  $vbox -> Add($xesboxsizer, 0, wxGROW|wxALL, 5);

  my $xbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $xesboxsizer -> Add($xbox, 0, wxGROW|wxALL, 0);

  $self->{incident_label} = Wx::StaticText->new($self, -1, 'Incident energy');
  $self->{incident} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize);
  $xbox -> Add($self->{incident_label}, 0, wxGROW|wxALL, 5);
  $xbox -> Add($self->{incident}, 0, wxGROW|wxALL, 5);
  $app->mouseover($self->{incident}, "Select the incident energy at which to compute the XES.");

  $xbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $xesboxsizer -> Add($xbox, 0, wxGROW|wxALL, 0);

  $self->{xes} = Wx::Button->new($self, -1, 'Process &XES', wxDefaultPosition, [$button_width,-1]);
  $xbox -> Add($self->{xes}, 0, wxGROW|wxALL, 5);
  $self->{replot_xes} = Wx::Button->new($self, -1, 'Replot XES', wxDefaultPosition, [$button_width,-1]);
  $xbox -> Add($self->{replot_xes}, 0, wxGROW|wxALL, 5);
  $self->{save_xes} = Wx::Button->new($self, -1, 'Save XES data', wxDefaultPosition, [$button_width,-1]);
  $xbox -> Add($self->{save_xes}, 0, wxGROW|wxALL, 5);
  $self->{xes_rixs} = Wx::Button->new($self, -1, 'RIXS map', wxDefaultPosition, [$button_width,-1]);
  $xbox -> Add($self->{xes_rixs}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{xes},        sub{plot_xes(@_, $app)});
  EVT_BUTTON($self, $self->{replot_xes}, sub{replot_xes(@_, $app)});
  EVT_BUTTON($self, $self->{save_xes},   sub{save_xes(@_, $app)});
  EVT_BUTTON($self, $self->{xes_rixs},   sub{xes_rixs(@_, $app)});
  $app->mouseover($self->{xes}, "Process XES data at the selected incident energy.");
  $app->mouseover($self->{replot_xes}, "Replot the last XES spectrum.");
  $app->mouseover($self->{save_xes},   "Save the last XES data to a column data file.");
  $app->mouseover($self->{xes_rixs},   "Plot a map of the RIXS in the XES direction.");

  $self->{showmasks} = Wx::CheckBox->new($self, -1, "Show masks as they are created");
  $xbox -> Add($self->{showmasks}, 0, wxGROW|wxALL, 0);
  $self->{showmasks}->SetValue(1);


  $vbox->Add(1,30,0);

  my $rixsbox       = Wx::StaticBox->new($self, -1, ' RIXS ', wxDefaultPosition, wxDefaultSize);
  my $rixsboxsizer  = Wx::StaticBoxSizer->new( $rixsbox, wxHORIZONTAL );
  $vbox -> Add($rixsboxsizer, 0, wxGROW|wxALL, 5);

  $self->{rixs} = Wx::Button->new($self, -1, 'Process R&IXS', wxDefaultPosition, [$button_width,-1]);
  $rixsboxsizer -> Add($self->{rixs}, 0, wxGROW|wxALL, 5);
  $self->{replot_rixs} = Wx::Button->new($self, -1, 'Replot RIXS', wxDefaultPosition, [$button_width,-1]);
  $rixsboxsizer -> Add($self->{replot_rixs}, 0, wxGROW|wxALL, 5);
  $self->{save_rixs} = Wx::Button->new($self, -1, 'Save RIXS data', wxDefaultPosition, [$button_width,-1]);
  $rixsboxsizer -> Add($self->{save_rixs}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{rixs},        sub{plot_rixs(@_, $app)});
  EVT_BUTTON($self, $self->{replot_rixs}, sub{replot_rixs(@_, $app)});
  EVT_BUTTON($self, $self->{save_rixs},   sub{save_rixs(@_, $app)});
  $app->mouseover($self->{rixs}, "Process RIXS data,i.e. HERFD at all emission energies.");
  $app->mouseover($self->{replot_rixs}, "Replot the last RIXS data.");
  $app->mouseover($self->{save_rixs},   "Save the last DATA data to an Athena project file.");

  $self->{rshowmasks} = Wx::CheckBox->new($self, -1, "Show masks as they are created");
  $rixsboxsizer -> Add($self->{rshowmasks}, 0, wxGROW|wxALL, 0);
  $self->{rshowmasks}->SetValue(1);


  foreach my $k (qw(stub energylabel herfd replot_herfd save_herfd mue showmasks
		    incident incident_label
		    xes replot_xes save_xes xes_rixs rixs replot_rixs save_rixs rshowmasks)) {
    $self->{$k}->Enable(0);
  };


  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub restore {
  my ($self) = @_;
  foreach my $k (qw(stub energylabel herfd replot_herfd save_herfd mue showmasks
		    incident incident_label
		    xes replot_xes save_xes xes_rixs rixs replot_rixs save_rixs rshowmasks)) {
    $self->{$k}->Enable(0);
  };
  $self->{herfdbox}->SetLabel(' HERFD');
  $self->{incident}->SetValue('');
};

sub fetch_steps {
  my ($self, $spectrum, $app) = @_;
  ## read step list, add andmask if needed
  my $steplist = $app->{Mask}->{steps_list};
  if ($steplist->GetString($steplist->GetCount-1) ne 'andmask') {
    $steplist->Append("andmask");
  };
  $spectrum->clear_steps;
  foreach my $n (0 .. $steplist->GetCount-1) {
    $spectrum->push_steps($steplist->GetString($n));
  };
  return $spectrum->steps;
};

######################################################################
## HERFD

sub plot_herfd {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();

  my $start = DateTime->now( time_zone => 'floating' );

  my $np = $app->{Files}->{image_list}->GetCount;
  my $spectrum = $app->{bla_of}->{$self->{energy}};
  $spectrum->sentinal(sub{$app->{main}->status("Processing point ".$_[0]." of $np", 'wait')});

  my %args = ();
  $args{write}   = q{};
  $args{verbose} = 0;
  $args{unity}   = 0;
  ## make sure the AND mask step has been done.  doing it twice has no impact
  $spectrum -> do_step('andmask', %args);
  $spectrum -> npixels($spectrum->elastic_image->sum);
  my $rsteps = $self->fetch_steps($spectrum, $app);


  my $steplist = $app->{Mask}->{steps_list};
  if ($steplist->GetString($steplist->GetCount-1) ne 'andmask') {
    $steplist->Append("andmask");
  };
  $spectrum->clear_steps;
  foreach my $n (0 .. $app->{Mask}->{steps_list}->GetCount-1) {
    $spectrum->push_steps($app->{Mask}->{steps_list}->GetString($n));
  };

  my $image_list = $app->{Files}->{image_list};
  foreach my $i (0 .. $image_list->GetCount-1) {
    $spectrum->push_scan_file_list(File::Spec->catfile($spectrum->tifffolder, $image_list->GetString($i)));
  };

  my $ret = $spectrum -> scan(verbose=>0, xdiini=>q{});
  my $title = $spectrum->stub . ' at ' . $spectrum->energy;

  my $toss = Demeter::Data->new();
  $spectrum->herfd_demeter($toss->put($spectrum->xdata, $spectrum->ydata, datatype=>'xanes'));
  $spectrum->herfd_demeter->put_data;
  $spectrum->herfd_demeter->_update('background');
  $spectrum->mue_demeter($toss->put($spectrum->xdata, $spectrum->mudata, datatype=>'xanes'));
  $spectrum->mue_demeter->put_data;
  $spectrum->mue_demeter->_update('background');
  undef $toss;

  $spectrum -> plot_xanes(title=>$title, pause=>0, mue=>$self->{mue}->GetValue);
  $spectrum->sentinal(sub{1});
  $self->{$_} -> Enable(1) foreach (qw(replot_herfd save_herfd));
  $self->{herfdbox}->SetLabel(' HERFD ('.$spectrum->energy.')');
  $self->{current} = $spectrum->energy;
  $app->set_parameters;	    # save config file becasue, presumably, we like the current mask creation values
  $app->{main}->status("Plotted HERFD with emission energy = " .
		       $spectrum->energy .
		       $spectrum->howlong($start, '.  That'));
  undef $busy;
};

sub replot_herfd {
  my ($self, $event, $app) = @_;
  my $spectrum = $app->{bla_of}->{$self->{energy}};
  my $title = $spectrum->stub . ' at ' . $self->{current};
  $spectrum -> plot_xanes(title=>$title, pause=>0, mue=>$self->{mue}->GetValue);
  $app->{main}->status("Replotted HERFD with emission energy = ".$self->{current});
};

sub save_herfd {
  my ($self, $event, $app) = @_;
  my $spectrum = $app->{bla_of}->{$self->{energy}};
  my $fname = sprintf("%s_%d.dat", $spectrum->stub, $self->{current});
  my $fd = Wx::FileDialog->new( $app->{main}, "Save data file", cwd, $fname,
				"DAT (*.dat)|*.dat|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving data file canceled.");
    return;
  };
  my $file = $fd->GetPath;
  copy(File::Spec->catfile($spectrum->outfolder, $fname), $file);
  $app->{main}->status("Saved HERFD to ".$file);
};

######################################################################
## XES

sub select_incident {
  my ($self, $event, $app) = @_;
  $self->{xesout} = q{};
  unlink($self->{xesout}) if ($self->{xesout} and (-e $self->{xesout}));
  $self->{replot_xes} -> Enable(0);
  $self->{save_xes}   -> Enable(0);
};

sub plot_xes {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );

  my $spectrum  = $app->{bla_of}->{$self->{energy}};

  my $rsteps = $self->fetch_steps($spectrum, $app);

  my $incident  = $self->{incident}->GetValue;
  my $diff = 999999;
  my $ni = 0;
  my $nincident = $ni;
  foreach my $in (@{$spectrum->incident_energies}) {
    if (abs($incident - $in) < $diff) {
      $diff = abs($incident - $in);
      $nincident = $ni;
    };
    ++$ni;
  };
  $incident = $spectrum->incident_energies->[$nincident];
  return if (not $incident);
  $self->{incident}->SetValue($incident);

  my $file = File::Spec->catfile($app->{bla_of}->{$self->{energy}}->tifffolder,
				 $app->{Files}->{image_list}->GetString($nincident));
  my $point = $app->{bla_of}->{$self->{energy}}->Read($file);

  my ($r, $x, $n, @xes);
  my $max = 0;
  foreach my $key (sort keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');
    $app->{bla_of}->{$key}->incident($incident);
    $app->{bla_of}->{$key}->nincident($nincident);
    #my $lca = List::Compare->new('-u', '-a', $rsteps, $app->{bla_of}->{$key}->steps);
    #if (not $lca->is_LequivalentR()) {

    ## push step list to rest of project
    $app->{bla_of}->{$key}->steps($rsteps);
    $app->{bla_of}->{$key}->mask(elastic=>basename($app->{bla_of}->{$key}->elastic_file),
				 aggregate=>$app->{bla_of}->{aggregate});
    $r = $point -> mult($app->{bla_of}->{$key}->elastic_image, 0) -> sum;
    $n = $app->{bla_of}->{$key}->npixels;
    $max = $n if ($n > $max);
    $x = $r/$n;
    push @xes, [$key, $x, $n, $r];
    if ($self->{showmasks}->GetValue) {
      $app->{bla_of}->{$key}->cbmax(1);
      $app->{bla_of}->{$key}->plot_mask;
    };
  };
  #my $max = max(@n);
  #@n = map {$max / $_} @n;
  foreach my $key (keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');
    $app->{bla_of}->{$key}->normpixels($max/$app->{bla_of}->{$key}->npixels);
  };

  $self->{xesout} = $app->{bla_of}->{$self->{energy}}->plot_xes(pause=>0, incident=>$incident, xes=>\@xes);
  $self->{xesdata} = \@xes;

  $self->{replot_xes} -> Enable(1);
  $self->{save_xes}   -> Enable(1);
  $self->{xes_rixs}   -> Enable(1);
  $app->{main}->status("Plotted XES with incident energy = " .
		       $incident .
		       Xray::BLA->howlong($start, '.  That'));
  undef $busy;

};

sub replot_xes {
  my ($self, $event, $app) = @_;
  my $incident  = $self->{incident}->GetValue;
  my $spectrum = $app->{bla_of}->{$self->{energy}};
  $self->{xesout} = $spectrum->plot_xes(pause=>0, incident=>$incident, xes=>$self->{xesdata});
  $app->{main}->status("Replotted XES with incident energy = ".$self->{incident}->GetValue);
};

sub save_xes {
  my ($self, $event, $app) = @_;
  my $spectrum = $app->{bla_of}->{$self->{energy}};
  my $fname = sprintf("%s_%d.xes", $spectrum->stub, $spectrum->incident);
  my $fd = Wx::FileDialog->new( $app->{main}, "Save XES data file", cwd, $fname,
				"XES (*.xes)|*.xes|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving data file canceled.");
    return;
  };
  my $file = $fd->GetPath;
  copy($self->{xesout}, $file);
  $app->{main}->status("Saved XES to ".$file);
};

sub xes_rixs {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );

  my $spectrum = $app->{bla_of}->{$self->{energy}};

  ## bring all the masks up to date
  $app->{main}->status("Computing masks for each emission energy ...", 'wait');
  my $rsteps = $self->fetch_steps($spectrum, $app);

  foreach my $key (sort keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');
    my $lca = List::Compare->new('-u', '-a', $rsteps, $app->{bla_of}->{$key}->steps);
    if (not $lca->is_LequivalentR()) {
      $app->{bla_of}->{$key}->steps($rsteps);
      $app->{bla_of}->{$key}->mask(elastic=>basename($app->{bla_of}->{$key}->elastic_file),
				   aggregate=>$app->{bla_of}->{aggregate});
      if ($self->{showmasks}->GetValue) {
	$app->{bla_of}->{$key}->cbmax(1);
	$app->{bla_of}->{$key}->plot_mask;
      };
    };
  };

  open(my $RIXS, '>', File::Spec->catfile($spectrum->outfolder, $spectrum->stub.'.rixs'));
  my $rixs;
  my @vals = ();

  $app->{main}->status("Computing XES at each incident energy ...", 'wait');
  my ($ni, $ne, $file, $point, $r, $n, $x) = (0, 0, q{}, q{}, 0, 0, 0);
  foreach my $inc (@{$spectrum->incident_energies}) {
    $file = File::Spec->catfile($spectrum->tifffolder,
				$app->{Files}->{image_list}->GetString($ni));
    $point = $spectrum->Read($file);

    $app->{main}->status("Computing XES at each incident energy ... " . $ni . ' of ' . $#{$spectrum->incident_energies}, 'wait') if (not $ni % 15);

    $ne = 0;
    foreach my $key (sort keys %{$app->{bla_of}}) {
      next if ($key eq 'aggregate');
      $app->{bla_of}->{$key}->incident($inc);
      $app->{bla_of}->{$key}->nincident($ni);
      $r = $point -> mult($app->{bla_of}->{$key}->elastic_image, 0) -> sum;
      $n = $app->{bla_of}->{$key}->npixels;
      $x = $r/$n;
      $rixs->[$ne]->[$ni] = $x;
      printf $RIXS "%.3f   %.3f   %.8g\n", $key, $inc, $x;
      $ne++;
    };
    $ni ++;

    print $RIXS $/;
  };

  close $RIXS;

  #image({cbrange=>[0,3], palette=>$spectrum->palette, title=>'RIXS',
 # 	 xlabel=>'incident energy (eV)', ylabel=>'emission energy (eV)', cblabel=>'emission'},
 # 	PDL->new($rixs));


  $app->{main}->status("Plotted RIXS map calculated along the XES direction" . Xray::BLA->howlong($start, '.  That'));

  undef $busy;
};


######################################################################
## RIXS


sub plot_rixs {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );

  my $spectrum  = $app->{bla_of}->{$self->{energy}};

  ## bring this mask up to date
  my $rsteps = $self->fetch_steps($spectrum, $app);

  my $image_list = $app->{Files}->{image_list};
  foreach my $i (0 .. $image_list->GetCount-1) {
    $spectrum->push_scan_file_list(File::Spec->catfile($spectrum->tifffolder, $image_list->GetString($i)));
  };
  my $sfl = $spectrum->scan_file_list;

  my @sorted_list;
  my $max = 0;
  foreach my $key (sort keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');

    #my $lca = List::Compare->new('-u', '-a', $rsteps, $app->{bla_of}->{$key}->steps);
    #if (not $lca->is_LequivalentR()) {
      $app->{main}->status("Computing mask for emission energy ".$app->{bla_of}->{$key}->energy, 'wait');
      $app->{bla_of}->{$key}->steps($rsteps); # bring all the masks up to date
      $app->{bla_of}->{$key}->mask(elastic=>basename($app->{bla_of}->{$key}->elastic_file),
				   aggregate=>$app->{bla_of}->{aggregate});
      if ($self->{rshowmasks}->GetValue) {
	$app->{bla_of}->{$key}->cbmax(1);
	$app->{bla_of}->{$key}->plot_mask;
      };
    #};
    $max = $app->{bla_of}->{$key}->npixels if ($app->{bla_of}->{$key}->npixels > $max);
    $app->{bla_of}->{$key}->scan_file_list($sfl);
    $app->{main}->status("Computing HERFD for emission energy ".$app->{bla_of}->{$key}->energy, 'wait');
    my $ret = $app->{bla_of}->{$key} -> scan(verbose=>0, xdiini=>q{});
    push @sorted_list, $app->{bla_of}->{$key};

    my $toss = Demeter::Data->new();
    $app->{bla_of}->{$key}->herfd_demeter($toss->put($app->{bla_of}->{$key}->xdata,
						     $app->{bla_of}->{$key}->ydata, datatype=>'xanes', name=>$key));
    $app->{bla_of}->{$key}->herfd_demeter->put_data;
    $app->{bla_of}->{$key}->herfd_demeter->_update('background');
    $app->{bla_of}->{$key}->mue_demeter($toss->put($app->{bla_of}->{$key}->xdata,
						   $app->{bla_of}->{$key}->mudata, datatype=>'xanes', name=>'conventional'));
    $app->{bla_of}->{$key}->mue_demeter->put_data;
    $app->{bla_of}->{$key}->mue_demeter->_update('background');
    undef $toss;

  };
  foreach my $key (keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');
    $app->{bla_of}->{$key}->normpixels($max / $app->{bla_of}->{$key}->npixels);
  };

  $spectrum->plot_rixs(@sorted_list);

  $self->{replot_rixs} -> Enable(1);
  $self->{save_rixs}   -> Enable(1);
  $app->{main}->status("Plotted RIXS as XAFS-like data" . Xray::BLA->howlong($start, '.  That'));
};

sub replot_rixs {
  my ($self, $event, $app) = @_;
  my $spectrum  = $app->{bla_of}->{$self->{energy}};
  my @list;
  foreach my $key (sort keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');
    push @list, $app->{bla_of}->{$key};
  };
  $spectrum->plot_rixs(@list);
  $app->{main}->status("Replotted RIXS as XAFS-like data.");
};

sub save_rixs {
  my ($self, $event, $app) = @_;
  my @list = ();
  foreach my $key (sort keys %{$app->{bla_of}}) {
    next if ($key eq 'aggregate');
    push @list, $app->{bla_of}->{$key}->herfd_demeter;
  };
  my $fname = sprintf("%s_rixs.prj", $app->{base}->stub);
  my $fd = Wx::FileDialog->new( $app->{main}, "Save RIXS data to Athena project file", cwd, $fname,
				"Athena project file (*.prj)|*.prj|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving Athena project file canceled.");
    return;
  };
  my $file = $fd->GetPath;
  $list[0]->write_athena($file, @list);
  $app->{main}->status("Safe XAFS-like RIXS to an Athena project file.");
};


1;


=head1 NAME

Demeter::UI::Metis::Data - Metis' data processing tool

=head1 VERSION

This documentation refers to Xray::BLA version 2.

=head1 DESCRIPTION

Metis is a graphical interface the Xray::BLA package for processing
data from an energy dispersive bent Laue analyzer spectrometer in
which the signal is dispersed onto the face of a Pilatus camera.

The Data tool is used to process a sequence of images into a HERFD,
XES, or RIXS spectra.  The result can be plotted or saved to
appropriate output files.

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

