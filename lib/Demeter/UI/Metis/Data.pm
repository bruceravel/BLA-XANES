package Demeter::UI::Metis::Data;

use strict;
use warnings;

use Cwd;
use File::Copy;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw( EVT_BUTTON);

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
  $self->{energy} = Wx::StaticText->new($self, -1, 'Current mask energy is <undefined>');
  $vbox -> Add($self->{energy}, 0, wxGROW);

  $vbox->Add(1,30,0);

  my $button_width = 125;

  my $herfdbox       = Wx::StaticBox->new($self, -1, ' HERFD ', wxDefaultPosition, wxDefaultSize);
  my $herfdboxsizer  = Wx::StaticBoxSizer->new( $herfdbox, wxHORIZONTAL );
  $vbox -> Add($herfdboxsizer, 1, wxGROW|wxALL, 5);
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

  $vbox->Add(1,30,0);

  my $xesbox       = Wx::StaticBox->new($self, -1, ' XES ', wxDefaultPosition, wxDefaultSize);
  my $xesboxsizer  = Wx::StaticBoxSizer->new( $xesbox, wxHORIZONTAL );
  $vbox -> Add($xesboxsizer, 1, wxGROW|wxALL, 5);

  $self->{xes} = Wx::Button->new($self, -1, 'Process &XES', wxDefaultPosition, [$button_width,-1]);
  $xesboxsizer -> Add($self->{xes}, 0, wxGROW|wxALL, 5);
  $self->{replot_xes} = Wx::Button->new($self, -1, 'Replot XES', wxDefaultPosition, [$button_width,-1]);
  $xesboxsizer -> Add($self->{replot_xes}, 0, wxGROW|wxALL, 5);
  $self->{save_xes} = Wx::Button->new($self, -1, 'Save XES data', wxDefaultPosition, [$button_width,-1]);
  $xesboxsizer -> Add($self->{save_xes}, 0, wxGROW|wxALL, 5);

  $vbox->Add(1,30,0);

  my $rixsbox       = Wx::StaticBox->new($self, -1, ' RIXS ', wxDefaultPosition, wxDefaultSize);
  my $rixsboxsizer  = Wx::StaticBoxSizer->new( $rixsbox, wxHORIZONTAL );
  $vbox -> Add($rixsboxsizer, 1, wxGROW|wxALL, 5);

  $self->{rixs} = Wx::Button->new($self, -1, 'Process R&IXS', wxDefaultPosition, [$button_width,-1]);
  $rixsboxsizer -> Add($self->{rixs}, 0, wxGROW|wxALL, 5);
  $self->{replot_rixs} = Wx::Button->new($self, -1, 'Replot RIXS', wxDefaultPosition, [$button_width,-1]);
  $rixsboxsizer -> Add($self->{replot_rixs}, 0, wxGROW|wxALL, 5);
  $self->{save_rixs} = Wx::Button->new($self, -1, 'Save RIXS data', wxDefaultPosition, [$button_width,-1]);
  $rixsboxsizer -> Add($self->{save_rixs}, 0, wxGROW|wxALL, 5);

  foreach my $k (qw(stub energy herfd replot_herfd save_herfd
		    xes replot_xes save_xes rixs replot_rixs save_rixs)) {
    $self->{$k}->Enable(0);
  };


  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub plot_herfd {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $np = $app->{Files}->{image_list}->GetCount;
  $app->{spectrum}->sentinal(sub{$app->{main}->status("Processing point ".$_[0]." of $np", 'wait')});
  my $ret = $app->{spectrum} -> scan(verbose=>0, xdiini=>q{});
  my $title = $app->{spectrum}->stub . ' at ' . $app->{spectrum}->energy;
  $app->{spectrum} -> plot_xanes($ret->message, title=>$title, pause=>0);
  $app->{spectrum}->sentinal(sub{1});
  $self->{replot_herfd} -> Enable(1);
  $self->{save_herfd}   -> Enable(1);
  $self->{herfdbox}->SetLabel(' HERFD ('.$app->{spectrum}->energy.')');
  $self->{current} = $app->{spectrum}->energy;
  $app->{main}->status("Plotted HERFD with emission energy = ".$app->{spectrum}->energy);
  undef $busy;
};

sub replot_herfd {
  my ($self, $event, $app) = @_;
  my $title = $app->{spectrum}->stub . ' at ' . $self->{current};
  $app->{spectrum} -> plot_xanes(q{}, title=>$title, pause=>0);
  $app->{main}->status("Replotted HERFD with emission energy = ".$self->{current});
};

sub save_herfd {
  my ($self, $event, $app) = @_;
  my $fname = sprintf("%s_%d.dat", $app->{spectrum}->stub, $self->{current});
  my $fd = Wx::FileDialog->new( $app->{main}, "Save data file", cwd, $fname,
				"DAT (*.dat)|*.dat|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving data file canceled.");
    return;
  };
  my $file = $fd->GetPath;
  copy(File::Spec->catfile($app->{spectrum}->outfolder, $fname), $file);
  $app->{main}->status("Saved HERFD to ".$file);
};

1;
