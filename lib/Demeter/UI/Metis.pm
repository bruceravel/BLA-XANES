package Demeter::UI::Metis;

use Demeter qw(:hephaestus);
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
use Wx::Perl::Carp;

my $icon_dimension = 30;
my @utilities = qw(Files Mask Data Config);

use Const::Fast;
const my $Files  => Wx::NewId();
const my $Mask   => Wx::NewId();
const my $Data   => Wx::NewId();
const my $Config => Wx::NewId();
const my $Object => Wx::NewId();
const my $About  => Wx::NewId();


sub OnInit {
  my ($app) = @_;

  $app->{main} = Wx::Frame->new(undef, -1, 'Metis [BLA data processing]', wxDefaultPosition, [850,550],);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "metis_icon.png");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);
  #EVT_CLOSE($app->{main}, sub{$app->on_close($_[1])});

  $app->{main}->{header_color} = Wx::Colour->new(68, 31, 156);
  $app->{base} = Xray::BLA->new(ui=>'wx', cleanup=>0, masktype=>'single');
  $app->{base} -> task('herfd');
  $app->{base} -> outfolder(File::Spec->catfile($app->{base}->stash_folder,
						'metis-'.$app->{base}->randomstring(5)));

  $app->{yamlfile} = File::Spec->catfile($app->{base}->dot_folder, 'metis.yaml');
  if (-e $app->{yamlfile}) {
    $app->{yaml} = YAML::Tiny -> read($app->{yamlfile});
    foreach my $k (qw(stub scanfolder tifffolder element line color div10)) {
      $app->{base}->$k($app->{yaml}->[0]->{$k}) if defined $app->{yaml}->[0]->{$k};
    };
    foreach my $c (qw(imagescale tiffcounter energycounterwidth outimage terminal
		      scan_file_template elastic_file_template image_file_template
		      xdi_metadata_file)) {
      $app->{base}->$c($app->{yaml}->[0]->{$c}) if defined $app->{yaml}->[0]->{$c};
    };
    foreach my $m (qw(bad_pixel_value weak_pixel_value social_pixel_value
		      lonely_pixel_value scalemask radius)) {
      $app->{base}->$m($app->{yaml}->[0]->{$m}) if defined $app->{yaml}->[0]->{$m};
    };
  } else {
    $app->{yaml} = YAML::Tiny -> new;
  };
  $app->{base}->set_palette($app->{base}->color);

  $app->{bla_of}= {};
  $app->{bla_of}->{aggregate}  = $app->{base}->clone();
  $app->{bla_of}->{aggregate} -> cleanup(1);
  $app->{bla_of}->{aggregate} -> masktype('aggregate');

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
  $filemenu->Append(wxID_EXIT, "E&xit\tCtrl+q" );

  my $helpmenu   = Wx::Menu->new;
  $helpmenu->Append($Object,   "View Xray::BLA attributes\tCtrl+0" );
  $helpmenu->AppendSeparator;
  $helpmenu->Append($About,    "About Metis" );

  $bar->Append( $filemenu,     "&Metis" );
  $bar->Append( $helpmenu,     "&Help" );
  $app->{main}->SetMenuBar( $bar );
  EVT_MENU($app->{main}, -1, sub{my ($frame,  $event) = @_; OnMenuClick($frame, $event, $app)} );

  $app->{main} -> Show( 1 );
  $app->{main} -> Refresh;
  $app->{main} -> Update;
  $app->{main} -> status("Welcome to Metis version $Xray::BLA::VERSION, copyright 2012-2014,2016 Bruce Ravel, Jeremy Kropf");

  $app->{main} -> SetSizer($vbox);

  $app->{Config}->{line}->SetSize(($app->{Config}->GetSizeWH)[0], 2);

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
    ($id == $About)   and do {
      $app->on_about;
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

  ## set values for base object
  $app->{base} -> stub(get_symbol($app->{Files}->{stub}->GetValue));
  $app->{base} -> element(get_symbol($app->{Files}->{element}->GetSelection+1));
  $app->{base} -> line($app->{Files}->{line}->GetStringSelection);
  $app->{base} -> scanfolder($app->{Files}->{scan_dir}->GetLabel);
  $app->{base} -> tifffolder($app->{Files}->{image_dir}->GetLabel);
  $app->{base} -> div10($app->{Files}->{div10}->GetValue);

  $app->{base} -> imagescale($app->{Config}->{imagescale}->GetValue);
  $app->{base} -> tiffcounter($app->{Config}->{tiffcounter}->GetValue);
  $app->{base} -> energycounterwidth($app->{Config}->{energycounterwidth}->GetValue);
  $app->{base} -> terminal($app->{Config}->{terminal}->GetStringSelection);
  $app->{base} -> outimage($app->{Config}->{outimage}->GetStringSelection);
  $app->{base} -> color($app->{Config}->{color}->GetStringSelection);
  $app->{base} -> set_palette($app->{base}->color);
  $app->{base} -> scan_file_template($app->{Config}->{scan_file_template}->GetValue);
  $app->{base} -> elastic_file_template($app->{Config}->{elastic_file_template}->GetValue);
  $app->{base} -> image_file_template($app->{Config}->{image_file_template}->GetValue);
  $app->{base} -> xdi_metadata_file($app->{Config}->{xdi_filename}->GetLabel);

  $app->{base} -> bad_pixel_value($app->{Mask}->{badvalue}->GetValue);
  $app->{base} -> weak_pixel_value($app->{Mask}->{weakvalue}->GetValue);
  $app->{base} -> social_pixel_value($app->{Mask}->{socialvalue}->GetValue);
  $app->{base} -> lonely_pixel_value($app->{Mask}->{lonelyvalue}->GetValue);
  $app->{base} -> scalemask($app->{Mask}->{multiplyvalue}->GetValue);
  $app->{base} -> radius($app->{Mask}->{arealvalue}->GetValue);

  $app->{yaml}->[0]->{stub} = $app->{Files}->{stub}->GetValue;
  foreach my $k (qw(scanfolder tifffolder element line color palette
		    imagescale outimage terminal energycounterwidth tiffcounter
		    scan_file_template elastic_file_template image_file_template xdi_metadata_file
		    bad_pixel_value weak_pixel_value social_pixel_value
		    lonely_pixel_value scalemask radius div10
		  )) {
    ## push values into yaml
    $app->{yaml}->[0]->{$k} = $app->{base}->$k;

    ## and push these values onto all of $app->{bla_of}
    foreach my $key (keys %{$app->{bla_of}}) {
      $app->{bla_of}->{$key}->$k($app->{base}->$k);
    };
  };
  $app->{yaml}->write($app->{yamlfile});

  return $app;
};

sub view_attributes {
  my ($app) = @_;
  my $which = $app->{book}->GetPageText($app->{book}->GetSelection);
  my $spectrum = $app->{base};
  my $id = 'base';
  if ($which eq 'Mask') {
    my $en = $app->{Mask}->{energy}->GetStringSelection;
    if ($app->{Mask}->{rbox}->GetStringSelection =~ m{Single} and $en) {
      $spectrum = $app->{bla_of}->{$en};
      $id = $en;
    } elsif ($app->{Mask}->{rbox}->GetStringSelection =~ m{Aggregate}) {
      $spectrum = $app->{bla_of}->{aggregate};
      $id = 'aggregate';
    };
  } elsif ($which eq 'Data') {
    my $en = $app->{Data}->{energy};
    $spectrum = $app->{bla_of}->{$en} if $en;
      $id = $en;
  };

  my $text = $spectrum->attribute_report;
  if (ref($spectrum->herfd_demeter) =~ m{Demeter}) {
    $text .= "\n\nHERFD Demeter object:\n\n";
    $text .= $spectrum->herfd_demeter->serialization;
  };
  if (ref($spectrum->mue_demeter) =~ m{Demeter}) {
    $text .= "\n\nConventional mu(E) Demeter object:\n\n";
    $text .= $spectrum->mue_demeter->serialization;
  };

  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($app->{main}, $text, "Structure of \"$id\" object")
      -> Show;
};


sub on_about {
  my ($app) = @_;

  my $info = Wx::AboutDialogInfo->new;

  $info->SetName( 'Metis' );
  $info->SetVersion( $Xray::BLA::VERSION );
  $info->SetDescription( "Bent Laue analyzer + Pilatus data processing" );
  $info->SetCopyright( "copyright © 2012-2014, 2016, Bruce Ravel, Jeremy Kropf" );
  $info->SetWebSite( 'https://github.com/bruceravel/BLA-XANES', 'Metis at GitHub' );
  $info->SetDevelopers( ["Bruce Ravel <bravel AT bnl DOT gov>\n" ] );
  $info->SetArtists( ["Metis logo cropped from\nhttp://commons.wikimedia.org/wiki/File:Winged_goddess_Louvre_F32.jpg\n",
		      "Files and Config icons from the gartoon icon theme\nhttp://gnome-look.org/content/show.php/Gartoon+Icon+theme+%28v0.4.5%29?content=13527\n",
		      "Mask icon cropped from\nhttp://en.wikipedia.org/wiki/File:Ancient_iranian_mask.jpg\n",
		      "Data icon is the gnuplot icon"
		     ] );
  #$info->SetLicense( Demeter->slurp(File::Spec->catfile($athena_base, 'Athena', 'share', "GPL.dem")) );

  Wx::AboutBox( $info );
}



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

This documentation refers to Xray::BLA version 2.

=head1 DESCRIPTION

Metis is a graphical interface the Xray::BLA package for processing
data from an energy dispersive bent Laue analyzer spectrometer in
which the signal is dispersed onto the face of a Pilatus camera.

=head1 DEPENDENCIES

Xray::BLA and Metis dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

See F<todo.org>

Please report problems as issues at the github site
L<https://github.com/bruceravel/BLA-XANES>

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/BLA-XANES/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

