package Demeter::UI::Metis::PluckPoint;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX EVT_CHOICE);

sub new {
  my ($class, $parent, $energy, $x, $y, $r) = @_;
  $r ||= 3;

  my $this = $class->SUPER::new($parent, -1, "Metis: Edit a spot",
				Wx::GetMousePosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );
  #$vbox -> Add(Wx::StaticText->new($this, -1, "Edit a path parameter"), 0, wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( wxHORIZONTAL );
  $vbox -> Add($gbs, 0, wxGROW|wxALL, 5);
  $this->{elabel} = Wx::StaticText->new($this, -1, "Energy (range)");
  $this->{xlabel} = Wx::StaticText->new($this, -1, "X position");
  $this->{ylabel} = Wx::StaticText->new($this, -1, "Y position");
  $this->{rlabel} = Wx::StaticText->new($this, -1, "Radius");
  $gbs->Add($this->{elabel}, Wx::GBPosition->new(0,0));
  $gbs->Add($this->{xlabel}, Wx::GBPosition->new(0,1));
  $gbs->Add($this->{ylabel}, Wx::GBPosition->new(0,2));
  $gbs->Add($this->{rlabel}, Wx::GBPosition->new(0,3));

  $this->{e} = Wx::TextCtrl->new($this, -1, $energy, wxDefaultPosition, [120,-1]);
  $this->{x} = Wx::TextCtrl->new($this, -1, $x,      wxDefaultPosition, [120,-1]);
  $this->{y} = Wx::TextCtrl->new($this, -1, $y,      wxDefaultPosition, [120,-1]);
  $this->{r} = Wx::TextCtrl->new($this, -1, $r,      wxDefaultPosition, [120,-1]);
  $gbs->Add($this->{e}, Wx::GBPosition->new(1,0));
  $gbs->Add($this->{x}, Wx::GBPosition->new(1,1));
  $gbs->Add($this->{y}, Wx::GBPosition->new(1,2));
  $gbs->Add($this->{r}, Wx::GBPosition->new(1,3));




  $this->{ok} = Wx::Button->new($this, wxID_OK, "Add this spot", wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $vbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);


  $this -> SetSizerAndFit( $vbox );
  return $this;
};


sub ShouldPreventAppExit {
  0
};

1;

=head1 NAME

Demeter::UI::Metis::PluckPoint - Widget for defining a spot for removal from an image

=head1 VERSION

See Xray::BLA

=head1 SYNOPSIS

This module provides a dialog for defining a spot in an image to be
removed during the bad/weak step in a recipe.  This dialog prompts an
energy, an x/y position, and a radius, whihc are returned as a
white-space separate string.

    my $pp = Demeter::UI::Metis::PluckPoint->new($self, $self->{energy}->GetStringSelection, $x, $y);
    if ($pp->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Making spot canceled.");
      return;
    };
    my $line = join("  ",  $pp->{e}->GetValue, $pp->{x}->GetValue, $pp->{y}->GetValue, $pp->{r}->GetValue);

The energy part of this string can refer to a single energy or an
energy range using this syntax:

=over 4

=item C<energy>

This refers to the elastic image a specific energy.  For example:

   11191

=item C<emin-emax>

This refers to a range of elastic energies, inclusive.  For example:

   11194-11196

It is important that there be no white space around the dash.

=item C<emin+>

This refers to a range of elastic energies beginning at the specified
value and going to the end of the data set.  For example:

    11198+

It is important that there be no white space around the plus sign..

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014,2016 Bruce Ravel and Jeremy Kropf.  All rights
reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
