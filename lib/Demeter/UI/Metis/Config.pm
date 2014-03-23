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

  $self->{imagescale_label} = Wx::StaticText -> new($self, -1, "Scaling factor for image plots");
  $self->{imagescale}       = Wx::TextCtrl   -> new($self, -1, $app->{spectrum}->imagescale, wxDefaultPosition, [150,-1]);
  $gbs -> Add($self->{imagescale_label},    Wx::GBPosition->new(0,0));
  $gbs -> Add($self->{imagescale},          Wx::GBPosition->new(0,1));
  $app->mouseover($self->{imagescale}, "This sets the colorbar scale of an image plot.  Bigger number -> smaller dynamic range.");

  $self->{tiffcounter_label} = Wx::StaticText -> new($self, -1, "TIFF counter");
  $self->{tiffcounter}       = Wx::TextCtrl   -> new($self, -1, $app->{spectrum}->tiffcounter, wxDefaultPosition, [150,-1]);
  $gbs -> Add($self->{tiffcounter_label},    Wx::GBPosition->new(1,0));
  $gbs -> Add($self->{tiffcounter},          Wx::GBPosition->new(1,1));
  $app->mouseover($self->{tiffcounter}, "The counter part of the name of the elastic TIFF file.");

  $self->{energycounterwidth_label} = Wx::StaticText -> new($self, -1, "Energy index width");
  $self->{energycounterwidth}       = Wx::SpinCtrl   -> new($self, -1, $app->{spectrum}->energycounterwidth, wxDefaultPosition, [150,-1], wxSP_ARROW_KEYS, 1, 6);
  $gbs -> Add($self->{energycounterwidth_label},    Wx::GBPosition->new(2,0));
  $gbs -> Add($self->{energycounterwidth},          Wx::GBPosition->new(2,1));
  $app->mouseover($self->{energycounterwidth}, "The width of the part of the TIFF file name for an energy point indicating the energy index.");

  $self->{imageformat_label} = Wx::StaticText -> new($self, -1, "Output image format");
  $self->{imageformat}       = Wx::Choice     -> new($self, -1, wxDefaultPosition, wxDefaultSize, [qw(gif tif)]);
  $gbs -> Add($self->{imageformat_label},    Wx::GBPosition->new(3,0));
  $gbs -> Add($self->{imageformat},          Wx::GBPosition->new(3,1));
  $self->{imageformat}->SetStringSelection($app->{spectrum}->imageformat);
  $app->mouseover($self->{imageformat}, "The file format used for static mask images.");

  $self->{set} = Wx::Button->new($self, -1, 'Set parameters');
  $gbs -> Add($self->{set},    Wx::GBPosition->new(4,0));
  EVT_BUTTON($self, $self->{set}, sub{$app->set_parameters});
  $app->mouseover($self->{set}, "Set parameters and save Metis' current configuration.");

## image scaling factor
## tiffcounter
## energycounterwidth
## image format

  $self -> SetSizerAndFit( $vbox );

  return $self;
};

1;
