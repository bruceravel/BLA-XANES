package Demeter::UI::Metis;

use strict;
use warnings;

use Xray::BLA;
use Demeter::UI::Artemis::ShowText;

use Chemistry::Elements qw(get_Z get_symbol);
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Scalar::Util qw(looks_like_number);
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
my @utilities = qw(Files Mask Data Config);

use Const::Fast;
const my $Files  => Wx::NewId();
const my $Mask   => Wx::NewId();
const my $Data   => Wx::NewId();
const my $Config => Wx::NewId();
const my $Object => Wx::NewId();


sub OnInit {
  my ($app) = @_;

  $app->{main} = Wx::Frame->new(undef, -1, 'Metis [BLA data processing]', wxDefaultPosition, [850,500],);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "metis_icon.png");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);
  #EVT_CLOSE($app->{main}, sub{$app->on_close($_[1])});

  $app->{main}->{header_color} = Wx::Colour->new(68, 31, 156);
  $app->{spectrum}  = Xray::BLA->new(ui=>'wx', cleanup=>1);
  $app->{spectrum} -> task('herfd');
  $app->{spectrum} -> outfolder(File::Spec->catfile($app->{spectrum}->stash_folder,
						    'metis-'.$app->{spectrum}->randomstring(5)));

  $app->{yamlfile} = File::Spec->catfile($app->{spectrum}->dot_folder, 'metis.yaml');
  if (-e $app->{yamlfile}) {
    $app->{yaml} = YAML::Tiny -> read($app->{yamlfile});
    foreach my $k (qw(stub scanfolder tifffolder element line)) {
      $app->{spectrum}->$k($app->{yaml}->[0]->{$k}) if defined $app->{yaml}->[0]->{$k};
    };
    foreach my $c (qw(imagescale tiffcounter energycounterwidth outimage)) {
      $app->{spectrum}->$c($app->{yaml}->[0]->{$c}) if defined $app->{yaml}->[0]->{$c};
    };
    foreach my $m (qw(bad_pixel_value weak_pixel_value social_pixel_value
		      lonely_pixel_value scalemask radius)) {
      $app->{spectrum}->$m($app->{yaml}->[0]->{$m}) if defined $app->{yaml}->[0]->{$m};
    };
  } else {
    $app->{yaml} = YAML::Tiny -> new;
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

  my $bar = Wx::MenuBar->new;
  my $filemenu   = Wx::Menu->new;
  $filemenu->Append($Files,    "Show Files tool\tCtrl+1" );
  $filemenu->Append($Mask,     "Show Mask tool\tCtrl+2" );
  $filemenu->Append($Data,     "Show Data tool\tCtrl+3" );
  $filemenu->Append($Config,   "Show Configuration tool\tCtrl+4" );
  $filemenu->AppendSeparator;
  $filemenu->Append($Object,   "View Xray::BLA attributes\tCtrl+0" );
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_EXIT, "E&xit\tCtrl+q" );
  $bar->Append( $filemenu,     "&Metis" );
  $app->{main}->SetMenuBar( $bar );
  EVT_MENU($app->{main}, -1, sub{my ($frame,  $event) = @_; OnMenuClick($frame, $event, $app)} );

  $app->{main} -> Show( 1 );
  $app->{main} -> Refresh;
  $app->{main} -> Update;
  $app->{main} -> status("Welcome to Metis version $Xray::BLA::VERSION, copyright 2012-2014 Bruce Ravel, Jeremy Kropf");

  $app->{main} -> SetSizer($vbox);
  return 1;
};

#sub on_close {
#  my ($app) = @_;
#  $app->Destroy;
#};

sub OnMenuClick {
  my ($self, $event, $app) = @_;
  my $id = (looks_like_number($event)) ? $event : $event->GetId;
 SWITCH: {
    ($id == $Files)    and do {
      $app->{book}->SetSelection(0);
      return;
    };
    ($id == $Mask)     and do {
      $app->{book}->SetSelection(1);
      return;
    };
    ($id == $Data)     and do {
      $app->{book}->SetSelection(2);
      return;
    };
    ($id == $Config)   and do {
      $app->{book}->SetSelection(3);
      return;
    };
    ($id == $Object)   and do {
      $app->view_attributes;
      return;
    };
    ($id == wxID_EXIT) and do {
      $self->Close;
      return;
    };
  };
};

sub mouseover {
  my ($app, $widget, $text) = @_;
  my $sb = $app->{main}->GetStatusBar;
  EVT_ENTER_WINDOW($widget, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($widget, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};

sub set_parameters {
  my ($app) = @_;
  $app->{spectrum} -> element(get_symbol($app->{Files}->{element}->GetSelection+1));
  $app->{spectrum} -> line($app->{Files}->{line}->GetStringSelection);
  $app->{spectrum} -> scanfolder($app->{Files}->{scan}->GetValue);
  $app->{spectrum} -> tifffolder($app->{Files}->{image}->GetValue);

  $app->{spectrum} -> imagescale($app->{Config}->{imagescale}->GetValue);
  $app->{spectrum} -> tiffcounter($app->{Config}->{tiffcounter}->GetValue);
  $app->{spectrum} -> energycounterwidth($app->{Config}->{energycounterwidth}->GetValue);
  $app->{spectrum} -> outimage($app->{Config}->{outimage}->GetStringSelection);

  $app->{spectrum} -> bad_pixel_value($app->{Mask}->{badvalue}->GetValue);
  $app->{spectrum} -> weak_pixel_value($app->{Mask}->{weakvalue}->GetValue);
  $app->{spectrum} -> social_pixel_value($app->{Mask}->{socialvalue}->GetValue);
  $app->{spectrum} -> lonely_pixel_value($app->{Mask}->{lonelyvalue}->GetValue);
  $app->{spectrum} -> scalemask($app->{Mask}->{multiplyvalue}->GetValue);
  $app->{spectrum} -> radius($app->{Mask}->{arealvalue}->GetValue);

  $app->{yaml}->[0]->{stub} = $app->{Files}->{stub}->GetValue;
  foreach my $k (qw(scanfolder tifffolder element line
		    imagescale outimage energycounterwidth tiffcounter
		    bad_pixel_value weak_pixel_value social_pixel_value
		    lonely_pixel_value scalemask radius
		  )) {
    $app->{yaml}->[0]->{$k} = $app->{spectrum}->$k;
  };
  $app->{yaml}->write($app->{yamlfile});

  return $app;
};

sub view_attributes {
  my ($app) = @_;
  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($app->{main}, $app->{spectrum}->attribute_report, 'Structure of Xray::BLA object')
      -> Show;

};


sub howlong {
  my ($self, $start, $id) = @_;
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->delta_ms($start);
  $id ||= 'That';
  my $text;
  if ($dur->minutes) {
    if ($dur->minutes == 1) {
      $text = sprintf "%s took %d minute and %d seconds.", $id, $dur->minutes, $dur->seconds;
    } else {
      $text = sprintf "%s took %d minutes and %d seconds.", $id, $dur->minutes, $dur->seconds;
    };
  } else {
    if ($dur->seconds == 1) {
      $text = sprintf "%s took %d second.", $id, $dur->seconds;
    } else {
      $text = sprintf "%s took %d seconds.", $id, $dur->seconds;
    };
  };
  return $text;
};




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

=head1 NAME

Demeter::UI::Metis - BLA data processing

=head1 VERSION

This documentation refers to Xray::BLA version 1.

=head1 DESCRIPTION

Metis is a graphical interface the Xray::BLA package for processing
data from an energy dispersive bent Laue analyzer spectrometer in
which the signal is dispersed onto the face of a Pilatus camera.

=head1 DEPENDENCIES

Xray::BLA and Metis's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

More error checking, edge cases.  For example, what happens when a
stub + folders does not return a sensible pile of stuff?

=item *

Persistance?  Is anything more than the preferences yaml necessary?

=item *

widgets for selecting folders

=item *

how are element and line used?  (needed to set white color band in a map)

=item *

implement XES and RIXS

=item *

Map and mapmask

=item *

aggregate map from set of elastic images

=item *

mask development animations.  according to the PERLDL mailing list,
giving file.gif to wmpeg will cause it to write an animated gif,
assuming ffmpeg is installed on the computer.  this needs testing
outside of metis.

=item *

some kind of system for specifying file naming patterns -- this is
somewhat less important now that the contents of the elastic and image
lists on the Files tool are used explicitly.  if this is still
ambiguous, a file selection dialog can be used to select content for
the lists.

=back

Please report problems as issues at the github site
L<https://github.com/bruceravel/BLA-XANES>

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/BLA-XANES/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
