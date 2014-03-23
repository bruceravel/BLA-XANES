package Demeter::UI::Metis::Data;

use strict;
use warnings;

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
  $self->{energy} = Wx::StaticText->new($self, -1, 'Emission energy is <undefined>');
  $vbox -> Add($self->{energy}, 0, wxGROW);

  $vbox->Add(1,30,0);

  $self->{herfd} = Wx::Button->new($self, -1, 'Process HERFD');
  $vbox -> Add($self->{herfd}, 0, wxGROW|wxALL, 5);
  $self->{save_herfd} = Wx::Button->new($self, -1, 'Save HERFD data');
  $vbox -> Add($self->{save_herfd}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  EVT_BUTTON($self, $self->{herfd}, sub{plot_herfd(@_, $app)});

  $vbox->Add(1,30,0);

  $self->{xes} = Wx::Button->new($self, -1, 'Process XES');
  $vbox -> Add($self->{xes}, 0, wxGROW|wxALL, 5);
  $self->{save_xes} = Wx::Button->new($self, -1, 'Save XES data');
  $vbox -> Add($self->{save_xes}, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  $vbox->Add(1,30,0);

  $self->{rixs} = Wx::Button->new($self, -1, 'Process RIXS');
  $vbox -> Add($self->{rixs}, 0, wxGROW|wxALL, 5);
  $self->{save_rixs} = Wx::Button->new($self, -1, 'Save RIXS data');
  $vbox -> Add($self->{save_rixs}, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  foreach my $k (qw(stub energy herfd save_herfd xes save_xes rixs save_rixs)) {
    $self->{$k}->Enable(0);
  };


  # my $herfdbox       = Wx::StaticBox->new($self, -1, ' HERFD ', wxDefaultPosition, wxDefaultSize);
  # my $herfdboxsizer  = Wx::StaticBoxSizer->new( $herfdbox, wxVERTICAL );
  # $vbox -> Add($herfdboxsizer, 1, wxGROW|wxALL, 5);

  # $self->{process} = Wx::Button->new($self, -1, 'Process HERFD');
  # $herfdboxsizer -> Add($self->{process}, 0, wxGROW);


  # my $xesbox       = Wx::StaticBox->new($self, -1, ' XES ', wxDefaultPosition, wxDefaultSize);
  # my $xesboxsizer  = Wx::StaticBoxSizer->new( $xesbox, wxVERTICAL );

  # #$self->{elastic_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  # #$elasticboxsizer -> Add($self->{elastic_list}, 1, wxGROW);
  # $vbox -> Add($xesboxsizer, 1, wxGROW|wxALL, 5);


  # my $rixsbox       = Wx::StaticBox->new($self, -1, ' RIXS ', wxDefaultPosition, wxDefaultSize);
  # my $rixsboxsizer  = Wx::StaticBoxSizer->new( $rixsbox, wxVERTICAL );

  # #$self->{elastic_list} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize);
  # #$elasticboxsizer -> Add($self->{elastic_list}, 1, wxGROW);
  # $vbox -> Add($rixsboxsizer, 1, wxGROW|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub plot_herfd {
  my ($self, $event, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $np = $app->{Files}->{image_list}->GetCount;
  $app->{spectrum}->sentinal(sub{$app->{main}->status("Processing point ".$_[0]." of $np")});
  my $ret = $app->{spectrum} -> scan(verbose=>0, xdiini=>q{});
  $app->{spectrum} -> plot_xanes($ret->message, title=>$app->{spectrum}->stub, pause=>0);
  $app->{spectrum}->sentinal(sub{1});
  undef $busy;
};


1;
