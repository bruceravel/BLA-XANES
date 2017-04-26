package Demeter::UI::Metis::UserMask;

use strict;
use warnings;

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_CHECKBOX EVT_FILEPICKER_CHANGED);

use PDL::Core qw(pdl ones zeros);
use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);

use Cwd;

sub new {
  my ($class, $parent, $spectrum, $fname) = @_;
  $fname ||= q{};

  my $this = $class->SUPER::new($parent, -1, "Metis: Select a user mask file",
				Wx::GetMousePosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  ## --- file picker
  my $hbox =  Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);
  $this->{file} = Wx::FilePickerCtrl->new($this, -1, $fname||cwd, 'Select a user mask',
					  "gif files (*.gif)|*.gif|TIF files (*.tif)|*.tif|All files|*.*", [-1,-1], [300,-1],
					  wxFLP_OPEN|wxFLP_FILE_MUST_EXIST|wxFLP_CHANGE_DIR);
  $hbox -> Add($this->{file}, 0, wxGROW|wxALL, 5);
  EVT_FILEPICKER_CHANGED($this, $this->{file}, sub{plot($this, $spectrum)});

  ## --- include the 0 or 1 regions of the mask
  $hbox =  Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);
  $this->{rbox} = Wx::RadioBox->new($this, -1, 'Mask parity', wxDefaultPosition, wxDefaultSize,
  				    ['include 0', 'include 1'], 1, wxRA_SPECIFY_ROWS);
  $hbox->Add($this->{rbox}, 0, wxALL, 5);
  EVT_RADIOBOX($this, $this->{rbox}, sub{plot($this, $spectrum)});
  $this->{rbox}->SetSelection($::app->{base}->user_mask_zero_one);

  ## --- flip the mask vertically?  usually, yes
  $hbox =  Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);
  $this->{flip} = Wx::CheckBox->new($this, -1, 'Flip image vertically');
  $hbox->Add($this->{flip}, 0, wxALL, 5);
  $this->{flip}->SetValue($::app->{base}->user_mask_flip);
  EVT_CHECKBOX($this, $this->{flip}, sub{plot($this, $spectrum)});

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, q{}, wxDefaultPosition, wxDefaultSize);
  $vbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);
  $this->{ok} = Wx::Button->new($this, wxID_OK, q{}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this -> SetSizerAndFit( $vbox );
  return $this;
  
};

sub plot {
  my ($this, $spectrum) = @_;
  my $usermask = rim($this->{file}->GetPath);

  if ($this->{rbox}->GetSelection == 0) {
    $usermask->inplace->eq(0,0);
  } else {
    $usermask->inplace->gt(0,0);
  };

  if ($this->{flip}->GetValue == 1) {
    my $foo = $usermask->slice('0:-1,-1:0');
    $usermask = $foo;
  };
  $spectrum->usermask($usermask);
  $spectrum->plot_usermask;
};


1;
