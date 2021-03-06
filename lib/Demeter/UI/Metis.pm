package Demeter::UI::Metis;

use Demeter qw(:hephaestus);
use Xray::BLA;
use Demeter::UI::Common::ShowText;
use Demeter::UI::Athena::Status;
use Demeter::UI::Metis::LastPlot;
use Demeter::UI::Metis::HDF5;

use Chemistry::Elements qw(get_Z get_symbol);
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Scalar::Util qw(looks_like_number);
use Text::Wrap;
use YAML::Tiny;

use PDL::IO::HDF5;
use PDL::Char;
use PDL::IO::Pic qw(rim);

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_RIGHT_UP EVT_LISTBOX EVT_RADIOBOX EVT_LISTBOX_DCLICK
		 EVT_TOOLBOOK_PAGE_CHANGED EVT_TOOLBOOK_PAGE_CHANGING
		 EVT_RIGHT_DOWN EVT_LEFT_DOWN EVT_CHECKLISTBOX
		 EVT_MENU EVT_CLOSE);
use base 'Wx::App';

use Wx::Perl::Carp qw(verbose);
$SIG{__WARN__} = sub { if ($_[0] =~ m{Reading ras files from sequential devices not supported}) { 1 } else { Wx::Perl::Carp::warn($_[0]) } };
$SIG{__DIE__}  = sub { if ($_[0] =~ m{Reading ras files from sequential devices not supported}) { 1 } else { Wx::Perl::Carp::warn($_[0]) } };

# use Sub::Override;
# my $override = Sub::Override->new('PDL::Core::barf',
# 				  sub {
# 				    print '>>>', $_[0], '<<<', $/;
# 				    if ($_[0] =~ m{Reading ras files from sequential devices not supported}) {
# 				      return;
# 				    }
# 				    Wx::Perl::Carp::warn($_[0]);
# 				  }
# 				 );


use Demeter::UI::Metis::Cursor;



my $icon_dimension = 30;

use Const::Fast;
const my $Files    => Wx::NewId();
const my $Mask     => Wx::NewId();
const my $Data     => Wx::NewId();
const my $Config   => Wx::NewId();
const my $XDI      => Wx::NewId();
const my $Import   => Wx::NewId();
const my $Object   => Wx::NewId();
const my $About    => Wx::NewId();
const my $Status   => Wx::NewId();
const my $Lastplot => Wx::NewId();

const my $INCREMENT_ENERGY   => Wx::NewId();
const my $DECREMENT_ENERGY   => Wx::NewId();
const my $OPEN               => Wx::NewId();
const my $SAVE               => Wx::NewId();

sub OnInit {
  my ($app, $tool) = @_;
  $app->{tool} = $::tool;
  $app->{save} = 0;
  my @utilities = ();
  if ($app->{tool} eq 'herfd') {
    @utilities = qw(Files Mask Data Config XDI);
  } elsif ($app->{tool} eq 'xes') {
    @utilities = qw(Files Mask Data Config XDI);
  } elsif ($app->{tool} =~ m{v?rxes}) {
    @utilities = qw(Files Mask Data Config XDI);
  } elsif ($app->{tool} eq 'mask') {
    @utilities = qw(Files Mask Config XDI);
  };

  $app->{main} = Wx::Frame->new(undef, -1, 'Metis for '.uc($app->{tool}).' [BLA data processing]', wxDefaultPosition, [850,550],);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "metis_icon.png");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);
  #EVT_CLOSE($app->{main}, sub{$app->on_close($_[1])});

  #$app->{save_icon}  = Wx::Bitmap->new(File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "Save.png"), wxBITMAP_TYPE_PNG);
  $app->{saved} = 0;
  $app->{from_project} = 0;

  $app->{main}->{Status} = Demeter::UI::Athena::Status->new($app->{main});
  $app->{main}->{Status}->SetTitle("Metis [Status Buffer]");

  $app->{main}->{Lastplot} = Demeter::UI::Metis::LastPlot->new($app->{main});
  $app->{main}->{Lastplot}->SetTitle("Metis [Last Plot]");

  $app->{main}->{header_color} = Wx::Colour->new(68, 31, 156);
  $app->{base} = Xray::BLA->new(ui=>'wx', cleanup=>0, masktype=>'single');
  my $task = ($app->{tool} =~ m{v?rxes}) ? 'plane' : $app->{tool}; # changed rxes-->vrxes 23 May 2017
  $app->{base} -> task($task);
  $app->{base} -> outfolder(File::Spec->catfile($app->{base}->stash_folder,
						'metis-'.$app->{base}->randomstring(5)));
  $app->{base} -> usermask(PDL::null);

  foreach my $p (qw(polyfill_order imagescale xdi_metadata_file tiffcounter terminal
		    energycounterwidth gaussian_kernel splot_palette_name color outimage
		    image_file_template scan_file_template elastic_file_template)) {
    $app->{base}->$p(Demeter->co->default('metis', $p));
  };

  ## --- make an HDF5 file and begin to populate it
  $app->init_hdf5(File::Spec->catfile($app->{base}->outfolder, "metis.mpj"));

  ## look for metis.<tool>.yaml or metis.yaml
  $app->{yamlfile} = File::Spec->catfile($app->{base}->dot_folder, join('.', 'metis', $app->{tool}, 'yaml'));
  if ($app->{tool} eq 'rxes') {	# deal with rxes --> vrxes name change
    my $vrxes = File::Spec->catfile($app->{base}->dot_folder, join('.', 'metis', 'vrxes', 'yaml'));
    move($app->{yamlfile}, $vrxes);
    $app->{yamlfile} = $vrxes;
    $app->{tool} = 'vrxes';
    $app->{main}->SetTitle('Metis for VRXES');
  };
  if ($app->{tool} eq 'vrxes') {	# deal with rxes --> vrxes name change
    my $rxes = File::Spec->catfile($app->{base}->dot_folder, join('.', 'metis', 'rxes', 'yaml'));
    move($rxes, $app->{yamlfile}) if (-e $rxes);
  };
  $app->{yamlfile} = File::Spec->catfile($app->{base}->dot_folder, join('.', 'metis', 'yaml')) if not -e $app->{yamlfile};
  if (-e $app->{yamlfile}) {
    $app->{yaml} = YAML::Tiny -> read($app->{yamlfile});
    foreach my $k (qw(stub scanfolder tifffolder element line color splot_palette_name div10 width_min width_max)) {
      $app->{base}->$k($app->{yaml}->[0]->{$k}) if defined $app->{yaml}->[0]->{$k};
    };
    foreach my $c (qw(imagescale tiffcounter energycounterwidth outimage terminal
		      scan_file_template elastic_file_template image_file_template
		      xdi_metadata_file)) {
      $app->{base}->$c($app->{yaml}->[0]->{$c}) if defined $app->{yaml}->[0]->{$c};
    };
    foreach my $m (qw(user_mask_file user_mask_zero_one user_mask_flip
		      bad_pixel_value weak_pixel_value exponent social_pixel_value
		      lonely_pixel_value scalemask radius gaussian_blur_value shield)) {
      $app->{base}->$m($app->{yaml}->[0]->{$m}) if defined $app->{yaml}->[0]->{$m};
    };
  } else {
    $app->{yaml} = YAML::Tiny -> new;
  };
  $app->{base}->set_palette($app->{base}->color);
  $app->{base}->set_splot_palette($app->{base}->splot_palette_name);

  if ((-f $app->{base}->user_mask_file) and ($app->{base}->usermask->isnull or $app->{base}->usermask->isempty)) {
    my $usermask = rim($app->{base}->user_mask_file);
    if ($app->{base}->user_mask_zero_one == 0) {
      $usermask->inplace->eq(0,0);
    } else {
      $usermask->inplace->gt(0,0);
    };
    if ($app->{base}->user_mask_flip) {
      my $foo = $usermask->slice('0:-1,-1:0');
      $usermask = $foo;
    };
    $app->{base}->usermask($usermask);
    my $ds = $app->{elastic_group}->dataset('usermask'); # make a data set in the elastic group for this energy
    $ds->set($app->{base}->usermask, unlimited => 1);    # put elastic image into hdf5 file

  };


  $app->{bla_of}= {};
  $app->{bla_of}->{aggregate}  = $app->{base}->clone();
  $app->{bla_of}->{aggregate} -> cleanup(1);
  $app->{bla_of}->{aggregate} -> masktype('aggregate');

  ## -------- status bar
  $app->{main}->{statusbar} = $app->{main}->CreateStatusBar;

  my $vbox = Wx::BoxSizer->new( wxVERTICAL);

  my $tb = Wx::Toolbook->new( $app->{main}, -1, wxDefaultPosition, wxDefaultSize, wxBK_LEFT|wxTB_NO_TOOLTIPS );
  $app->{book} = $tb;

  my $imagelist = Wx::ImageList->new( $icon_dimension, $icon_dimension );
  foreach my $utility (@utilities) {
    {
      local $SIG{__WARN__} = sub{1;};
      my $icon = File::Spec->catfile(dirname($INC{'Demeter/UI/Metis.pm'}), 'Metis', 'share', "$utility.png");
      $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
    };
  };

  $tb->AssignImageList( $imagelist );
  foreach my $utility (@utilities) {
    my $count = $tb->GetPageCount;
    my $page = Wx::Panel->new($tb, -1);
    $app->{$utility."_page"} = $page;
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $app->{$utility."_sizer"} = $box;
    $page -> SetSizer($box);

    if ($utility ne 'Save') {
      my $this = "Demeter::UI::Metis::$utility";
      require "Demeter/UI/Metis/$utility.pm";
      $app->{$utility} = $this -> new($page, $app);
      $box->Add($app->{$utility}, 1, wxGROW|wxALL, 0);
    }

    my $lab = $utility;
    $lab = 'Images'         if $utility eq 'Files';
    $lab = uc($app->{tool}) if $utility eq 'Data';
    $tb->AddPage($page, $lab, 0, $count);
  };
  $vbox -> Add($tb, 1, wxEXPAND|wxALL, 0);
  $app->{base} -> initialize_plot;

  my $bar = Wx::MenuBar->new;
  my $filemenu   = Wx::Menu->new;
  $filemenu->Append($OPEN,     "Open Metis project file\tCtrl+o");
  $filemenu->Append($SAVE,     "Save Metis project file\tCtrl+s");
  $filemenu->AppendSeparator;
  $filemenu->Append($Files,    "Show Files tool\tCtrl+1");
  $filemenu->Append($Mask,     "Show Mask tool\tCtrl+2" );
  $filemenu->Append($Data,     "Show ".uc($app->{tool})." tool\tCtrl+3") if $app->{tool} ne q{mask};
  $filemenu->Append($Config,   "Show Configuration tool\tCtrl+4");
  $filemenu->Append($XDI,      "Show XDI (metadata) tool\tCtrl+5");
  $filemenu->AppendSeparator;
  $filemenu->Append($Import,   "Import configuration\tCtrl+i");
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_EXIT, "E&xit\tCtrl+q" );

  my $helpmenu   = Wx::Menu->new;
  $helpmenu->Append($Object,   "View Xray::BLA attributes\tCtrl+0" );
  $helpmenu->Append($Status,   "Show status buffer" );
  $helpmenu->Append($Lastplot, "Show last Gnuplot script" );
  $helpmenu->AppendSeparator;
  $helpmenu->Append($About,    "About Metis" );

  $bar->Append( $filemenu,     "&Metis" );
  $bar->Append( $helpmenu,     "&Help" );
  $app->{main}->SetMenuBar( $bar );
  EVT_MENU($app->{main}, -1, sub{my ($frame,  $event) = @_; OnMenuClick($frame, $event, $app)} );

  Wx::ToolTip::Enable(0);

  my $accelerator = Wx::AcceleratorTable->new(
   					      [wxACCEL_CTRL, 107, $INCREMENT_ENERGY],
   					      [wxACCEL_CTRL, 106, $DECREMENT_ENERGY],
   					      #[wxACCEL_ALT,  107, $MOVE_UP],
   					      #[wxACCEL_ALT,  106, $MOVE_DOWN],
   					     );
  $app->{main}->SetAcceleratorTable( $accelerator );

  $app->{main} -> Show( 1 );
  $app->{main} -> Refresh;
  $app->{main} -> Update;
  $app->{main} -> status("Welcome to Metis version $Xray::BLA::VERSION, copyright 2012-2014,2016 Bruce Ravel, Jeremy Kropf");

  $app->{main} -> SetSizerAndFit($vbox);

  #$app->{Config}->{line}->SetSize(($app->{Config}->GetSizeWH)[0], 2);
  #$app->{Config}->{xdi_filename}->SetSize((0.8*$app->{Config}->GetSizeWH)[0], 30);
  $app->{Mask}->{line}->SetSize(int(2*($app->{Mask}->GetSizeWH)[0]/3), 2);
  $app->{Mask}->{line2}->SetSize(int(2*($app->{Mask}->GetSizeWH)[0]/3), 2);
  EVT_CLOSE( $app->{main},  \&on_close);

  ## --- finally, put some more configuration in the HDF5 file
  $app->{configuration}->attrSet($_ => $app->{base}->$_) foreach (qw(color energycounterwidth gaussian_kernel imagescale outimage
								     polyfill_gaps polyfill_order splot_palette_name terminal
								     tiffcounter xdi_metadata_file));

  my $busy = Wx::BusyCursor->new();
  $app->{book}->Enable(0);	# some visual feedback, wait for HDF5 import
  $app->{book}->Refresh;
  $app->open_hdf5($::hdf5file) if $::hdf5file;
  $app->{book}->Enable(1);
  undef $busy;

  return 1;
};

sub save_indicator {
  my ($app, $should_save) = @_;
  my $current = $app->{main}->GetTitle();
  $current =~ s{\A\* }{};
  $current =~ s{ \*\z}{};
  if ($should_save) {
    $app->{main}->SetTitle('* ' . $current . ' *');
    #$app->{Mask}->{savesteps}->SetBackgroundColour(Wx::Colour->new(255,206,215));
  } else {
    $app->{main}->SetTitle($current);
    #$app->{Mask}->{savesteps}->SetBackgroundColour($app->{Mask}->{restoresteps}->GetBackgroundColour);
  };
  $app->{save} = $should_save;
};


sub on_close {
  my ($app) = @_;
  if ($::app->{save}) {
    my $md = Wx::MessageDialog->new($app->{main}, "Save project before leaving?", "Save project before leaving?",
  				    wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION|wxSTAY_ON_TOP);
    my $answer = $md->ShowModal;
    return            if $answer == wxID_CANCEL;
    $::app->save_hdf5 if $answer == wxID_YES;
  };
  $app->Destroy;
};

## $state --  1 = saved  0 = needs saving
sub indicate_state {
  my ($self, $state) = @_;
  $::app->{saved} = $state;
  if ($state) {
    $::app->{$_}->{save} -> SetBackgroundColour( $::app->{Files}->{fetch}->GetBackgroundColour ) foreach (qw(Files Mask Config XDI));
    $::app->{$_}->{save} -> Enable(0) foreach (qw(Files Mask Config XDI));
    if ($::app->{tool} ne 'mask') {
      $::app->{Data}->{save} -> SetBackgroundColour( $::app->{Files}->{fetch}->GetBackgroundColour );
      $::app->{Data}->{save} -> Enable(0);
    };
  } else {
    $::app->{$_}->{save} -> SetBackgroundColour( Wx::Colour->new(255,206,215) ) foreach (qw(Files Mask Config XDI));
    $::app->{Data}->{save} -> SetBackgroundColour( Wx::Colour->new(255,206,215) ) if ($::app->{tool} ne 'mask');
  };
};


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
      my $n = ($app->{tool} eq q{mask}) ? 2 : 3;
      $app->{book}->SetSelection($n);
      return;
    };
    ($id == $XDI)   and do {
      my $n = ($app->{tool} eq q{mask}) ? 3 : 4;
      $app->{book}->SetSelection($n);
      return;
    };
    ($id == $Object)   and do {
      $app->view_attributes;
      return;
    };
    ($id == $Import)   and do {
      $app->restore_config;
      return;
    };
    ($id == $About)    and do {
      $app->on_about;
      return;
    };
    ($id == $Status) and do {
      $app->{main}->{Status} -> Show(1);
      last SWITCH;
    };
    ($id == $Lastplot) and do {
      $app->{main}->{Lastplot} -> Show(1);
      last SWITCH;
    };
    ($id == $INCREMENT_ENERGY) and do {
      return if ($app->{book}->GetSelection != 1);
      $app->{Mask}->spin_energy('up', $app);
      return;
    };
    ($id == $DECREMENT_ENERGY) and do {
      return if ($app->{book}->GetSelection != 1);
      $app->{Mask}->spin_energy('down', $app);
      return;
    };
    ($id == $OPEN) and do {
      $app->open_hdf5;
      return;
    };
    ($id == $SAVE) and do {
      #if ($::app->{Files}->{save} -> IsEnabled) {
	$app->save_hdf5;
	$app->save_indicator(0);
      #} else {
	#$app->{main}->status("Metis project file ".$app->{hdf5file}." is being automatically updated.", 'alert');
      #};
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
  $app->{base} -> stub($app->{Files}->{stub}->GetValue);
  $app->{base} -> element(get_symbol($app->{Files}->{element}->GetSelection+1));
  $app->{base} -> line($app->{Files}->{line}->GetStringSelection);
  $app->{base} -> scanfolder($app->{Files}->{scan_dir}->GetValue);
  $app->{base} -> tifffolder($app->{Files}->{image_dir}->GetValue);
  $app->{base} -> div10($app->{Files}->{div10}->GetValue);

  $app->{base} -> scan_file_template($app->{Files}->{scan_template}->GetValue);
  $app->{base} -> elastic_file_template($app->{Files}->{elastic_template}->GetValue);
  $app->{base} -> image_file_template($app->{Files}->{image_template}->GetValue);

  $app->{base} -> imagescale(Demeter->co->default('metis', 'imagescale'));
  $app->{base} -> tiffcounter(Demeter->co->default('metis', 'tiffcounter'));
  $app->{base} -> energycounterwidth(Demeter->co->default('metis', 'energycounterwidth'));
  $app->{base} -> terminal(Demeter->co->default('metis', 'terminal'));
  $app->{base} -> outimage(Demeter->co->default('metis', 'outimage'));
  $app->{base} -> color(Demeter->co->default('metis', 'color'));
  $app->{base} -> set_palette($app->{base}->color);
  $app->{base} -> splot_palette_name(Demeter->co->default('metis', 'splot_palette_name'));
  $app->{base} -> set_splot_palette($app->{base}->splot_palette_name);
  $app->{base} -> xdi_metadata_file(Demeter->co->default('metis', 'xdi_metadata_file'));
  $app->{base} -> gaussian_kernel(Demeter->co->default('metis', 'gaussian_kernel'));
  $app->{base} -> polyfill_order(Demeter->co->default('metis', 'polyfill_order'));

  my $val = $app->{Mask}->{gaussianvalue}->GetValue;
  if (not looks_like_number($val)) { # the only non-number the validator will pass
    my @list = split(/\./, $val);    # is something like 1.2.3, so presume the
    $val = join('.', @list[0,1]);    # trailing . is a mistake
  };

  $app->{base} -> width_min($app->{Mask}->{rangemin}->GetValue);
  $app->{base} -> width_max($app->{Mask}->{rangemax}->GetValue);
  $app->{base} -> user_mask_file($app->{Mask}->{usermaskfile}->GetValue);
  $app->{base} -> bad_pixel_value($app->{Mask}->{badvalue}->GetValue);
  $app->{base} -> weak_pixel_value($app->{Mask}->{weakvalue}->GetValue);
  $app->{base} -> exponent($app->{Mask}->{exponentvalue}->GetValue);
  $app->{base} -> gaussian_blur_value($val);
  $app->{base} -> shield($app->{Mask}->{shieldvalue}->GetValue);
  $app->{base} -> social_pixel_value($app->{Mask}->{socialvalue}->GetValue);
  $app->{base} -> lonely_pixel_value($app->{Mask}->{lonelyvalue}->GetValue);
  #$app->{base} -> scalemask($app->{Mask}->{multiplyvalue}->GetValue);
  $app->{base} -> radius($app->{Mask}->{arealvalue}->GetValue);

  ## shield

  $app->{yaml}->[0]->{stub} = $app->{Files}->{stub}->GetValue;
  foreach my $k (qw(scanfolder tifffolder element line color palette splot_palette_name
		    imagescale outimage terminal energycounterwidth tiffcounter
		    scan_file_template elastic_file_template image_file_template xdi_metadata_file
		    gaussian_kernel
		    user_mask_file user_mask_zero_one user_mask_flip
		    bad_pixel_value gaussian_blur_value shield weak_pixel_value exponent social_pixel_value
		    lonely_pixel_value scalemask radius div10 shield width_min width_max
		  )) {
    ## push values into yaml
    $app->{yaml}->[0]->{$k} = $app->{base}->$k;

    ## and push these values onto all of $app->{bla_of}
    foreach my $key (keys %{$app->{bla_of}}) {
      $app->{bla_of}->{$key}->$k($app->{base}->$k);
    };
  };
  $app->{yamlfile} = File::Spec->catfile($app->{base}->dot_folder, join('.', 'metis', $app->{tool}, 'yaml')) if ($app->{yamlfile} =~ m{metis\.yaml\z});
  $app->{yaml}->write($app->{yamlfile});

  ## --- finally, update configuration in the HDF5 file
  ##       Config
  $app->{configuration}->attrSet($_ => $app->{base}->$_) foreach (qw(color energycounterwidth gaussian_kernel imagescale outimage
								     polyfill_gaps polyfill_order splot_palette_name terminal
								     tiffcounter xdi_metadata_file));
  ##       Files
  $app->{configuration}->attrSet(stub             => $app->{Files}->{stub}->GetValue);
  $app->{configuration}->attrSet(element          => get_symbol($app->{Files}->{element}->GetSelection+1));
  $app->{configuration}->attrSet(line             => $app->{Files}->{line}->GetStringSelection);
  $app->{configuration}->attrSet(scan_folder      => $app->{Files}->{scan_dir}->GetValue);
  $app->{configuration}->attrSet(image_folder     => $app->{Files}->{image_dir}->GetValue);
  $app->{configuration}->attrSet(scan_template    => $app->{Files}->{scan_template}->GetValue);
  $app->{configuration}->attrSet(elastic_template => $app->{Files}->{elastic_template}->GetValue);
  $app->{configuration}->attrSet(image_template   => $app->{Files}->{image_template}->GetValue);
  $app->{configuration}->attrSet(div10            => $app->{Files}->{div10}->GetValue);
  ##       Mask
  $app->{configuration}->attrSet(width_min	      => $app->{Mask}->{rangemin}->GetValue);
  $app->{configuration}->attrSet(width_max	      => $app->{Mask}->{rangemax}->GetValue);
  $app->{configuration}->attrSet(bad_pixel_value      => $app->{Mask}->{badvalue}->GetValue);
  $app->{configuration}->attrSet(weak_pixel_value     => $app->{Mask}->{weakvalue}->GetValue);
  $app->{configuration}->attrSet(exponent	      => $app->{Mask}->{exponentvalue}->GetValue);
  $app->{configuration}->attrSet(user_mask_file	      => $app->{Mask}->{usermaskfile}->GetValue);
  $app->{configuration}->attrSet(gaussian_blur_value  => $val);
  $app->{configuration}->attrSet(shield		      => $app->{Mask}->{shieldvalue}->GetValue);
  $app->{configuration}->attrSet(social_pixel_value   => $app->{Mask}->{socialvalue}->GetValue);
  $app->{configuration}->attrSet(vertical	      => $app->{Mask}->{socialvertical}->GetValue);
  $app->{configuration}->attrSet(lonely_pixel_value   => $app->{Mask}->{lonelyvalue}->GetValue);
  # $app->{configuration}->attrSet(scalemask           => $app->{Mask}->{multiplyvalue}->GetValue);
  $app->{configuration}->attrSet(radius               => $app->{Mask}->{arealvalue}->GetValue);

  $app->{configuration}->attrSet(energy               => $app->{Data}->{energy});
  $app->{configuration}->attrSet(scanfile             => $app->{base}->scanfile);

  my $ds = $app->{configuration}->dataset('steps');
  my @steps = $app->{Mask}->{steps_list}->GetStrings;
  $ds->set(PDL::Char->new(\@steps), unlimited=>1) if $#steps > -1;

  $ds = $app->{configuration}->dataset('spots');
  my @spots = $app->{Mask}->{spots_list}->GetStrings;
  $ds->set(PDL::Char->new(\@spots), unlimited=>1) if $#spots > -1;

  $app->save_indicator(1);


  return $app;
};

sub restore_config {
  my ($app) = @_;
  my $fd = Wx::FileDialog->new( $app->{main}, "Restore configuration", cwd, q{},
				"INI (*.ini)|*.ini|All files (*)|*",
				wxFD_OPEN|wxFD_CHANGE_DIR|wxFD_FILE_MUST_EXIST,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Restoring configuration canceled.");
    return;
  };
  my $file = $fd->GetPath;
  tie my %ini, 'Config::IniFiles', ( -file => $file );

  $app->{Files}->{stub}      -> SetValue(basename($file, qw(.ini)));
  $app->{Files}->{scan_dir}  -> SetValue($ini{measure}{scanfolder});
  $app->{Files}->{image_dir} -> SetValue($ini{measure}{tiffolder});

  $app->{Files}->{element} -> SetValue($ini{measure}{element});
  $app->{Files}->{line}    -> SetValue($ini{measure}{line});
  $app->{Files}->{div10}   -> SetValue($ini{measure}{div10});

  $app->{Files}->{scan_template}    -> SetValue($ini{files}{scan});
  $app->{Files}->{elastic_template} -> SetValue($ini{files}{elastic});
  $app->{Files}->{image_template}   -> SetValue($ini{files}{image});
  $app->{Config}->{xdi_filename}     -> SetValue($ini{files}{xdi});

  $app->{Config}->{imagescale}         -> SetValue($ini{measure}{imagescale});
  $app->{Config}->{tiffcounter}        -> SetValue($ini{measure}{tiffcounter});
  $app->{Config}->{energycounterwidth} -> SetValue($ini{measure}{energycounterwidth});
  $app->{Config}->{outimage}           -> SetStringSelection($ini{measure}{outimage});
  $app->{Config}->{terminal}           -> SetStringSelection($ini{measure}{terminal});
  $app->{Config}->{color}              -> SetStringSelection($ini{measure}{color});
  $app->{Config}->{palette}            -> SetStringSelection($ini{measure}{palette});

  my $spots = $ini{spots}{spots};
  $spots = [$spots] if ref($spots) !~ m{ARRAY};
  $app->{Mask}->{spots_list}->Clear;
  foreach my $sp (@$spots) {
    next if not $sp;
    $app->{Mask}->{spots_list}->Append($sp);
  }
  my $steps = $ini{steps}{steps};
  $app->{Mask}->Reset(q{}, $app);
  foreach my $st (@$steps) {
    my @words = split(" ", $st);
    if ($st =~ m{\Abad}) {
      $app->{Mask}->{badvalue}->SetValue($words[1]);
      $app->{Mask}->{weakvalue}->SetValue($words[3]);
      $app->{Mask}->{exponentvalue}->SetValue($words[5] || 1);
    } elsif ($st =~ m{\Agaussian}) {
      $app->{Mask}->{gaussianvalue}->SetValue($words[1]);
    } elsif ($st =~ m{\A(?:use)?shield}) {
      $app->{Mask}->{shieldvalue}->SetValue($words[1]);
    } elsif ($st =~ m{\Asocial}) {
      $app->{Mask}->{socialvalue}->SetValue($words[1]);
    } elsif ($st =~ m{\Alonely}) {
      $app->{Mask}->{lonelyvalue}->SetValue($words[1]);
    #} elsif ($st =~ m{\Amultiply}) {
    #  $app->{Mask}->{multiplyvalue}->SetValue($words[1]);
    } elsif ($st =~ m{\Aareal}) {
      $app->{Mask}->{arealtype}->SetStringSelection($words[1]);
      $app->{Mask}->{arealvalue}->SetValue($words[1]);
    };
  };
};


sub view_attributes {
  my ($app) = @_;
  my $which = $app->{book}->GetPageText($app->{book}->GetSelection);
  my $spectrum = $app->{base};
  my $id = 'base';
  if ($which eq 'Mask') {
    my $en = $app->{Mask}->{energy}->GetStringSelection;
    #if ($app->{Mask}->{rbox}->GetStringSelection =~ m{Single} and $en) {
    #  $spectrum = $app->{bla_of}->{$en};
    #  $id = $en;
    #} elsif ($app->{Mask}->{rbox}->GetStringSelection =~ m{Aggregate}) {
    #  $spectrum = $app->{bla_of}->{aggregate};
    #  $id = 'aggregate';
    #};
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

  $text .= $/ x 3;
  $text .= "Elastic energies:\n";
  $text .= wrap("    ", "    ", join(" ", @{$app->{base}->elastic_energies})). $/;

  my $dialog = Demeter::UI::Common::ShowText
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
		      "Files and Config icons from the Gartoon Redux icon theme\nhttp://gnome-look.org/content/show.php/Gartoon+Redux?content=74841\n",
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
my $header = wxNullColour;
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
  $self->{Status}->put_text($text, $type);
  $self->Refresh;
};

package PDL::Graphics::Gnuplot;
{
  no warnings 'redefine';
  sub barf { goto &Carp::cluck };
}



1;

=head1 NAME

Demeter::UI::Metis - BLA data processing

=head1 VERSION

This documentation refers to Xray::BLA version 5.

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

