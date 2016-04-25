package  Demeter::UI::Metis::LastPlot;

=for Copyright
 .
 Copyright (c) 2011-2016 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
use warnings;

use Wx qw( :everything );
use Wx::Event qw(EVT_CLOSE EVT_BUTTON);
use base qw(Wx::Frame);
use Demeter::UI::Wx::Colours;

use Cwd;
use List::Util qw(max);

my @font = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" );
my @bold = (9, wxTELETYPE, wxNORMAL, wxFONTWEIGHT_BOLD, 0, "" );

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Metis [Last Plot]",
				wxDefaultPosition, [650,400],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  EVT_CLOSE($this, \&on_close);
  $this -> SetBackgroundColour( $wxBGC );
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $this->{name} = q{};
  my $id = q{}; #sprintf("[%s] %s (%s)\n", DateTime->now, 'Starting Artemis', Demeter->identify);
  $this->{text} = Wx::TextCtrl->new($this, -1, $id, wxDefaultPosition, wxDefaultSize,
				    wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL|wxTE_RICH2);
  $this->{text} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

  # $this->{normal} = Wx::TextAttr->new(Wx::Colour->new('#000000'), $wxBGC, Wx::Font->new( @font ) );
  # $this->{date}   = Wx::TextAttr->new(Wx::Colour->new('#acacac'), $wxBGC, Wx::Font->new( @font ) );
  # $this->{wait}   = Wx::TextAttr->new(Wx::Colour->new('#008800'), $wxBGC, Wx::Font->new( @font ) );
  # $this->{alert}  = Wx::TextAttr->new(Wx::Colour->new("#d9bf89"), $wxBGC, Wx::Font->new( @font ) );
  # $this->{error}  = Wx::TextAttr->new(Wx::Colour->new('#ffffff'), Wx::Colour->new("#aa0000"), Wx::Font->new( @bold ) );
  # $this->{header} = Wx::TextAttr->new(Wx::Colour->new('#000088'), $wxBGC, Wx::Font->new( @font ) );

  $vbox -> Add($this->{text}, 1, wxGROW, 0);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);

  $this->{clear} = Wx::Button->new($this, wxID_CLEAR, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{clear}, 1, wxGROW|wxRIGHT, 2);
  EVT_BUTTON($this, $this->{clear}, \&on_clear);

  $this->{save} = Wx::Button->new($this, wxID_SAVE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{save}, 1, wxGROW|wxRIGHT, 2);
  EVT_BUTTON($this, $this->{save}, \&on_save);

  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{close}, 1, wxGROW|wxLEFT, 2);
  EVT_BUTTON($this, $this->{close}, \&on_close);

  $this -> SetSizer($vbox);
  return $this;
};



sub on_save {
  my ($self) = @_;

  (my $pref = $self->{name}) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $self, "Save gnuplot script", cwd, q{splot.gp},
				"Gnuplot scripts (*.gp)|*.gp",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Not saving script buffer to script file.");
    return;
  };
  my $fname = $fd->GetPath;
  open (my $GP, '>',$fname);
  print $GP $self->{text}->GetValue;
  close $GP;
  $::app->{main}->status("Wrote gnuplot script file to '$fname'.");
};

sub on_clear {
  my ($self) = @_;
  $self->{text}->Clear;
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

sub put_text {
  my ($self, $text, $type) = @_;
  $self->{text}->Clear;
  $self->{text}->AppendText(sprintf "# [%s]\n\n", DateTime->now);
  $self->{text}->AppendText($text . "\n");

  # my $was = $self -> {text} -> GetInsertionPoint;
  # $self->{text}->AppendText(sprintf "[%s] ", DateTime->now);
  # my $is = $self -> {text} -> GetInsertionPoint;
  # $self->{text}->SetStyle($was, $is, $self->{date});

  # $was = $self -> {text} -> GetInsertionPoint;
  # $self->{text}->AppendText(sprintf " %s \n", $text);
  # $is = $self -> {text} -> GetInsertionPoint;
  # $self->{text}->SetStyle($was, $is, $self->{$type});
};

1;

=head1 NAME

Demeter::UI::Metis::LastPlot - A simple text buffer for Metis

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This module provides a window for displaying the previous plot script.

=head1 DEPENDENCIES

Metis's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems as issues at the gitghub site
(L<https://github.com/bruceravel/BLA-XANES/issues>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
