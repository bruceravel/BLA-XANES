package Demeter::UI::Metis::XDI;

use strict;
use warnings;

use Cwd;
use Const::Fast;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_TREE_ITEM_RIGHT_CLICK EVT_BUTTON EVT_MENU);

use Config::INI::Writer;

sub new {
  my ($class, $page, $app) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($hbox, 0, wxGROW|wxTOP|wxBOTTOM, 5);

  $self->{title} = Wx::StaticText->new($self, -1, "Metadata");
  $self->{title}->SetForegroundColour( $app->{main}->{header_color} );
  $self->{title}->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $hbox ->  Add($self->{title}, 1, wxGROW|wxALL, 5);

  # $self->{save} = Wx::BitmapButton->new($self, -1, $app->{save_icon});
  # $hbox ->  Add($self->{save}, 0, wxALL, 5);
  # EVT_BUTTON($self, $self->{save}, sub{$app->save_hdf5});
  # $app->mouseover($self->{save}, "Save this project to a Metis file.");



  $self->{tree} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, [-1,300],
				    wxTR_HIDE_ROOT|wxTR_SINGLE|wxTR_HAS_BUTTONS);
  $vbox -> Add($self->{tree}, 1, wxALL|wxGROW, 5);
  $self->{root} = $self->{tree}->AddRoot('Root');
  EVT_TREE_ITEM_RIGHT_CLICK($self, $self->{tree}, sub{OnRightClick(@_)});
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;
  $self->{tree}->SetFont( Wx::Font->new( $size - 1, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox ->  Add($hbox, 0, wxGROW|wxALL, 0);

  $self->{additem} = Wx::Button->new($self, -1, "Add item");
  $self->{clear}   = Wx::Button->new($self, -1, "Delete all");
  $self->{import}  = Wx::Button->new($self, -1, "Import metadata");
  $self->{savexdi}    = Wx::Button->new($self, -1, "Save metadata");
  $hbox ->  Add($self->{additem}, 1, wxGROW|wxALL, 5);
  $hbox ->  Add($self->{clear},   1, wxGROW|wxALL, 5);
  $hbox ->  Add($self->{import},  1, wxGROW|wxALL, 5);
  $hbox ->  Add($self->{savexdi},    1, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{additem}, sub{$_[0]->edit_item(q{}, q{}, q{})});
  EVT_BUTTON($self, $self->{clear},   sub{$_[0]->clear});
  EVT_BUTTON($self, $self->{import},  sub{$_[0]->Import($_[1], $app)});
  EVT_BUTTON($self, $self->{savexdi}, sub{$_[0]->save_xdi});

  $self->read_metadata(Demeter->co->default('metis', 'xdi_metadata_file'), $app);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub Import {
  my ($self, $event, $app) = @_;
  my $fd = Wx::FileDialog->new($::app->{main}, "Import metadata file", cwd, q{},
			       "INI (*.ini)|*.ini|All files (*)|*",
			       wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR,
			       wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Importing metadata file canceled.");
    return;
  };
  my $file = $fd->GetPath;
  $self->read_metadata($file, $app);
};


sub read_metadata {
  my ($self, $file, $app) = @_;
  if ($file and (-e $file)) {
    tie my %metadata, 'Config::IniFiles', ( -file => $file );
    if (exists $metadata{facility}->{source}) {
      if ($metadata{facility}->{source} =~ m{APS}) {
	$metadata{facility}->{name} = 'APS';
      };
      $metadata{facility}->{xray_source} = $metadata{facility}->{source};
      delete $metadata{facility}->{source};
    };
    $self->place_metadata(\%metadata, $app);
  };
};

sub place_metadata {
  my ($self, $rhash, $app) = @_;
  my %metadata = %$rhash;
  $self->{tree}->DeleteChildren($self->{root});
  foreach my $k (sort keys %metadata) {
    my $leaf = $self->{tree}->AppendItem($self->{root}, $k);
    $self->{tree} -> SetItemTextColour($leaf, wxWHITE );
    $self->{tree} -> SetItemBackgroundColour($leaf, wxBLACK );
    my $gp = $app->{metadata}->group(ucfirst(lc($k)));
    my $count = 0;
    foreach my $tag (sort keys %{$metadata{$k}}) {
      my $value = $metadata{$k}->{$tag};
      my $string = sprintf("%-20s = %-47s", lc($tag), $value);
      my $item = $self->{tree}->AppendItem($leaf, $string);
      $self->{tree} -> SetItemBackgroundColour($item,  ($count++ % 2) ? wxWHITE : wxLIGHT_GREY );
      $gp->attrSet(lc($tag) => $value);
      #printf("%s:%s = %s\n", $k, lc($tag), $value)
    };
    $self->{tree}->Expand($leaf);
  };
};



const my $EDIT   => Wx::NewId();
const my $ADD    => Wx::NewId();
const my $DELETE => Wx::NewId();

sub OnRightClick {
  my ($self, $event) = @_;
  my $item = $event->GetItem;
  my $family = $self->{tree}->GetItemText($self->{tree}->GetItemParent($item));
  $family =~ s{\s+\z}{};
  return if ($family eq 'Root');
  my ($name, $value) = split(/\s+=\s+/, $self->{tree}->GetItemText($item));

  my $menu  = Wx::Menu->new(q{});
  $menu->Append($EDIT,   "Edit ".ucfirst($family).".$name");
  $menu->Append($ADD,    "Add a parameter to ".ucfirst($family)." namespace");
  $menu->Append($DELETE, "Delete ".ucfirst($family).".$name");
  EVT_MENU($menu, -1, sub{ $self->DoContextMenu(@_, $family, $name, $value, $item) });
#  my $here = ($event =~ m{Mouse}) ? $event->GetPosition : Wx::Point->new(10,10);
  my $where = Wx::Point->new($event->GetPoint->x, $event->GetPoint->y+0);
  $self -> PopupMenu($menu, $where);

  $event->Skip(1);
};


sub DoContextMenu {
  my ($self, $menu, $event, $namespace, $parameter, $value, $item) = @_;
  $namespace =~ s{\A\s+}{}; # trim leading and trailing whitespace
  $parameter =~ s{\A\s+}{};
  $value     =~ s{\A\s+}{};
  $namespace =~ s{\s+\z}{}; # trim leading and trailing whitespace
  $parameter =~ s{\s+\z}{};
  $value     =~ s{\s+\z}{};
  my $action;
  if ($event->GetId == $EDIT) {
    $self->edit_item($namespace, $parameter, $value);
  } elsif ($event->GetId == $ADD) {
    $self->edit_item($namespace, q{}, q{});
  } elsif ($event->GetId == $DELETE) {
    $self->remove($namespace, $parameter, $item);
  };
  #print join("|", $action, $namespace, $parameter, $value), $/;
};


sub edit_item {
  my ($self, $namespace, $parameter, $value) = @_;
  my $dialog = Wx::Dialog->new($self, -1, "Metis: Edit a metadata item",
			       Wx::GetMousePosition, wxDefaultSize,
			       wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			      );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $gbs = Wx::GridBagSizer->new( wxHORIZONTAL );
  $vbox -> Add($gbs, 0, wxGROW|wxALL, 5);
  $dialog->{nlabel} = Wx::StaticText->new($dialog, -1, "Family");
  $dialog->{plabel} = Wx::StaticText->new($dialog, -1, "Item");
  $dialog->{vlabel} = Wx::StaticText->new($dialog, -1, "Value");
  $gbs->Add($dialog->{nlabel}, Wx::GBPosition->new(0,0));
  $gbs->Add($dialog->{plabel}, Wx::GBPosition->new(0,1));
  $gbs->Add($dialog->{vlabel}, Wx::GBPosition->new(0,2));

  $dialog->{n} = Wx::TextCtrl->new($dialog, -1, $namespace, wxDefaultPosition, [120,-1]);
  $dialog->{p} = Wx::TextCtrl->new($dialog, -1, $parameter, wxDefaultPosition, [120,-1]);
  $dialog->{v} = Wx::TextCtrl->new($dialog, -1, $value,     wxDefaultPosition, [300,-1]);
  $gbs->Add($dialog->{n}, Wx::GBPosition->new(1,0));
  $gbs->Add($dialog->{p}, Wx::GBPosition->new(1,1));
  $gbs->Add($dialog->{v}, Wx::GBPosition->new(1,2));

  $dialog->{v}->SetFocus;
  $dialog->{p}->SetFocus if ($parameter eq q{});
  $dialog->{n}->SetFocus if ($namespace eq q{});

  $dialog->{ok} = Wx::Button->new($dialog, wxID_OK, "Add metadata", wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($dialog->{ok}, 0, wxGROW|wxALL, 5);

  $dialog->{cancel} = Wx::Button->new($dialog, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $vbox -> Add($dialog->{cancel}, 0, wxGROW|wxALL, 5);
  $dialog -> SetSizerAndFit( $vbox );


  if ($dialog->ShowModal eq wxID_CANCEL) {
    $::app->{main}->status("Making spot canceled.");
    return;
  };

  $namespace = $dialog->{n}->GetValue;
  $parameter = $dialog->{p}->GetValue;
  $value     = $dialog->{v}->GetValue;

  my ($famitem, $cookie) = $self->{tree}->GetFirstChild($self->{root});
  while ($famitem->IsOk) {
    my $family = $self->{tree}->GetItemText($famitem);
    $family =~ s{\s+\z}{}; # trim trailing whitespace
    if (lc($family) eq lc($namespace)) {

      my ($count, $found) = (0,0);
      my ($nameitem, $cookie2) = $self->{tree}->GetFirstChild($famitem);
      while ($nameitem->IsOk) {
	++$count;
	my ($name, $oldvalue) = split(/\s*=\s*/, $self->{tree}->GetItemText($nameitem));
	$name =~ s{\A\s+}{};
	$name =~ s{\s+\z}{};

	## modify this leaf of the tree
	if (lc($name) eq lc($parameter)) {
	  $self->{tree}->SetItemText($nameitem, sprintf("%-20s = %-47s", lc($parameter), $value));
	  $self->{tree}->Refresh;
	  $found = 1;
	  $self->hdf5_put($namespace, $parameter, $value);
	  return;
	};
	($nameitem, $cookie2) = $self->{tree}->GetNextChild($famitem, $cookie2);
      };

      ## add to an existing branch of the tree
      if (not $found) {
	my $string = sprintf("%-20s = %-47s", lc($parameter), $value);
	my $item = $self->{tree}->AppendItem($famitem, $string);
	$self->{tree} -> SetItemBackgroundColour($item,  ($count % 2) ? wxWHITE : wxLIGHT_GREY );
	$self->hdf5_put($namespace, $parameter, $value);
	return;
      };
    };
    ($famitem, $cookie) = $self->{tree}->GetNextChild($self->{root}, $cookie);
  };

  ## or make a brand new entry in the tree
  my $string = sprintf("%-20s = %-47s", lc($parameter), $value);
  my $branch  = $self->{tree}->AppendItem($self->{root}, $namespace);
  $self->{tree} -> SetItemTextColour($branch, wxWHITE );
  $self->{tree} -> SetItemBackgroundColour($branch, wxBLACK );
  my $item = $self->{tree}->AppendItem($branch, $string);
  $self->{tree} -> SetItemBackgroundColour($item, wxLIGHT_GREY );
  $self->{tree}->Expand($branch);
  $self->hdf5_put($namespace, $parameter, $value);
};

sub hdf5_put {
  my ($self, $namespace, $parameter, $value) = @_;
  my $gp = $::app->{metadata}->group(ucfirst(lc($namespace)));
  $gp->attrSet(lc($parameter), $value);
  $::app->save_indicator(1);
};

sub remove {
  my ($self, $namespace, $parameter, $item) = @_;
  my $md = Wx::MessageDialog->new($self->{tree}, "Really delete \"$namespace.$parameter\"?", "Confirm deletion",
				  wxYES_NO|wxYES_DEFAULT|wxICON_QUESTION|wxSTAY_ON_TOP);
  if ($md->ShowModal == wxID_NO) {
    $::app->{main}->status("Not deleting item.");
    return;
  };
  $self->{tree}->Delete($item);
  $::app->{main}->status("Removed $namespace.$parameter");
};

sub clear {
  my ($self, $event) = @_;
  my $md = Wx::MessageDialog->new($self->{tree}, "Really delete ALL metadata?", "Confirm deletion",
				  wxYES_NO|wxNO_DEFAULT|wxICON_QUESTION|wxSTAY_ON_TOP);
  if ($md->ShowModal == wxID_NO) {
    $::app->{main}->status("Not deleting metadata.");
    return;
  };
  $self->{tree}->DeleteChildren($self->{root});
  $::app->{main}->status("Removed all metadata.");
};

sub save_xdi {
  my ($self, $menu, $event) = @_;

  my $spectrum = $::app->{base};
  my $fname = $spectrum->stub . ".ini";
  my $fd = Wx::FileDialog->new($::app->{main}, "Save metadata file", cwd, $fname,
			       "INI (*.ini)|*.ini|All files (*)|*",
			       wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
			       wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving metadata file canceled.");
    return;
  };
  my $file = $fd->GetPath;

  my %metadata;
  my ($famitem, $cookie) = $self->{tree}->GetFirstChild($self->{root});
  while ($famitem->IsOk) {
    my $family = $self->{tree}->GetItemText($famitem);
    $family =~ s{\s+\z}{}; # trim trailing whitespace
    my ($nameitem, $cookie2) = $self->{tree}->GetFirstChild($famitem);
    while ($nameitem->IsOk) {
      my ($name, $value) = split(/\s*=\s*/, $self->{tree}->GetItemText($nameitem));
      $name  =~ s{\A\s+}{};
      $name  =~ s{\s+\z}{};
      $value =~ s{\A\s+}{};
      $value =~ s{\s+\z}{};
      $metadata{$family}->{$name} = sprintf("%s", $value);
      ($nameitem, $cookie2) = $self->{tree}->GetNextChild($famitem, $cookie2);
    };
    ($famitem, $cookie) = $self->{tree}->GetNextChild($self->{root}, $cookie);
  };
  #use Data::Dump::Color;
  #dd \%metadata;

  Config::INI::Writer->write_file(\%metadata, $file);
  $::app->{main}->status("Wrote metadata to $file.");
};

sub fetch {
  my ($self) = @_;
  my %metadata;
  my ($famitem, $cookie) = $self->{tree}->GetFirstChild($self->{root});
  while ($famitem->IsOk) {
    my $family = $self->{tree}->GetItemText($famitem);
    $family =~ s{\s+\z}{}; # trim trailing whitespace
    my ($nameitem, $cookie2) = $self->{tree}->GetFirstChild($famitem);
    while ($nameitem->IsOk) {
      my ($name, $value) = split(/\s*=\s*/, $self->{tree}->GetItemText($nameitem));
      $name  =~ s{\A\s+}{};
      $name  =~ s{\s+\z}{};
      $value =~ s{\A\s+}{};
      $value =~ s{\s+\z}{};
      $metadata{$family}->{$name} = sprintf("%s", $value);
      ($nameitem, $cookie2) = $self->{tree}->GetNextChild($famitem, $cookie2);
    };
    ($famitem, $cookie) = $self->{tree}->GetNextChild($self->{root}, $cookie);
  };
  return \%metadata;
};


1;
