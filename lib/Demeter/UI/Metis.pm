package Demeter::UI::Metis;

use strict;
use warnings;

use Xray::BLA;

use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use YAML::Tiny;

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_RIGHT_UP EVT_LISTBOX EVT_RADIOBOX EVT_LISTBOX_DCLICK
		 EVT_CHOICEBOOK_PAGE_CHANGED EVT_CHOICEBOOK_PAGE_CHANGING
		 EVT_RIGHT_DOWN EVT_LEFT_DOWN EVT_CHECKLISTBOX
		 EVT_MENU EVT_CLOSE);
use base 'Wx::App';

my $icon_dimension = 30;
my @utilities = qw(Files Mask Data); # Help);

sub OnInit {
  my ($app) = @_;

  $app->{main} = Wx::Frame->new(undef, -1, 'Athena [XAS data processing]', wxDefaultPosition, [800,500],);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "metis_icon.png");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);
  #EVT_CLOSE($app->{main}, sub{$app->on_close($_[1])});

  $app->{main}->{header_color} = Wx::Colour->new(68, 31, 156);
  $app->{spectrum}  = Xray::BLA->new();
  $app->{spectrum} -> task('herfd');
  $app->{spectrum} -> outfolder(File::Spec->catfile($app->{spectrum}->stash_folder,
						    'metis-'.$app->{spectrum}->randomstring(5)));
  $app->{spectrum} -> cleanup(1);

  $app->{yamlfile} = File::Spec->catfile($app->{spectrum}->dot_folder, 'metis.yaml');
  if (-e $app->{yamlfile}) {
    $app->{yaml} = YAML::Tiny -> read($app->{yamlfile});
    foreach my $k (qw(stub scanfolder tifffolder element line)) {
      $app->{spectrum}->$k($app->{yaml}->[0]->{$k}) if defined $app->{yaml}->[0]->{$k};
    };
  };


  ## -------- status bar
  $app->{main}->{statusbar} = $app->{main}->CreateStatusBar;

  my $vbox = Wx::BoxSizer->new( wxVERTICAL);

  my $tb = Wx::Toolbook->new( $app->{main}, -1, wxDefaultPosition, wxDefaultSize, wxBK_LEFT );
  $app->{book} = $tb;

  my $imagelist = Wx::ImageList->new( $icon_dimension, $icon_dimension );
  foreach my $utility (@utilities) {
    my $icon = File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "$utility.png");
    $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
  };

  $tb->AssignImageList( $imagelist );
  foreach my $utility (@utilities) {
    my $count = $tb->GetPageCount;
    my $page = Wx::Panel->new($tb, -1);
    $app->{$utility."_page"} = $page;
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $app->{$utility."_sizer"} = $box;
    $page -> SetSizer($box);

    my $this = "Demeter::UI::Metis::$utility";
    require "Demeter/UI/Metis/$utility.pm";
    $app->{$utility} = $this -> new($page, $app);
    $box->Add($app->{$utility}, 1, wxGROW|wxALL, 0);

    $tb->AddPage($page, $utility, 0, $count);
  };
  $vbox -> Add($tb, 1, wxEXPAND|wxALL, 0);

  $app->{main} -> Show( 1 );
  $app->{main} -> Refresh;
  $app->{main} -> Update;
  $app->{main} -> status("Welcome to Metis");

  $app->{main} -> SetSizer($vbox);
  #$vbox -> Fit($tb);
  #$vbox -> SetSizeHints($tb);
  return 1;
};

#sub on_close {
#  my ($app) = @_;
#  $app->Destroy;
#};


package Wx::Frame;
use Wx qw(wxNullColour);
#use Demeter::UI::Wx::OverwritePrompt;
my $normal = wxNullColour;
my $wait   = Wx::Colour->new("#C5E49A");
my $alert  = Wx::Colour->new("#FCDD9F");
my $error  = Wx::Colour->new("#FD7E6F");
my $debug  = 0;
sub status {
  my ($self, $text, $type) = @_;
  $type ||= 'normal';

  if ($debug) {
    local $|=1;
    print $text, " -- ", join(", ", (caller)[0,2]), $/;
  };

  my $color = ($type =~ m{normal}) ? $normal
            : ($type =~ m{alert})  ? $alert
            : ($type =~ m{wait})   ? $wait
            : ($type =~ m{error})  ? $error
	    :                        $normal;
  $self->GetStatusBar->SetBackgroundColour($color);
  $self->GetStatusBar->SetStatusText($text);
  return if ($type =~ m{nobuffer});
  #$self->{Status}->put_text($text, $type);
  $self->Refresh;
};

1;
