package  Demeter::UI::Metis::HDF5;

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

use base qw( Exporter );
our @EXPORT = qw(init_hdf5 topof_hdf5 open_hdf5 save_hdf5);

use Cwd;
use File::Copy;
use PDL::IO::HDF5;
use Wx qw(:everything);

sub init_hdf5 {
  my ($app, $hdfile) = @_;
  ## --- make an HDF5 file and begin to populate it
  #my $hdfile = File::Spec->catfile($app->{base}->outfolder, "metis.hdf");
  #unlink($hdfile) if -e $hdfile;
  $app->topof_hdf5($hdfile);
  $app->{hdf5}         -> attrSet(name     => 'Metis');
  $app->{configuration}-> attrSet(mode     => $app->{tool});
  $app->{application}  -> attrSet(created  => DateTime->now);
  $app->{application}  -> attrSet(platform => $^O);
  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    $app->{application} -> attrSet(platform => join(', ', Win32::GetOSName(), Win32::GetOSVersion()));
  };
  $app->{application}  -> attrSet(Moose		   => $Moose::VERSION);
  $app->{application}  -> attrSet(PDL		   => $PDL::VERSION);
  $app->{application}  -> attrSet('PDL::IO::HDF5'  => $PDL::IO::HDF5::VERSION);
  $app->{application}  -> attrSet(Wx		   => $Wx::VERSION);
  $app->{application}  -> attrSet(wxWidgets	   => $Wx::wxVERSION_STRING);
  $app->{application}  -> attrSet(Perl		   => $]);
  $app->{application}  -> attrSet(Demeter	   => $Demeter::VERSION);
  $app->{application}  -> attrSet('Xray::BLA'	   => $Xray::BLA::VERSION);

};

sub topof_hdf5 {
  my ($app, $hdfile)    = @_;
  # if (exists $app->{hdf5}) {
  #   $app->{hdf5}->unlink('elastic');
  #   $app->{hdf5}->unlink('images');
  #   $app->{hdf5}->unlink('scan');
  #   $app->{hdf5}->unlink('metadata');
  #   $app->{hdf5}->unlink('configuration');
  #   $app->{hdf5}->unlink('application');
  # };
  $app->{hdf5}          = new PDL::IO::HDF5($hdfile);
  if (substr($hdfile, 0, 1) eq '>') { # opening for writing
    $hdfile = substr ($hdfile, 1);    # chop off >
  }
  $app->{hdf5file}      = $hdfile;
  $app->{elastic_group} = $app->{hdf5}->group("/elastic");
  $app->{image_group}   = $app->{hdf5}->group("/images");
  $app->{scan}          = $app->{hdf5}->group("/scan");
  $app->{metadata}      = $app->{hdf5}->group("/metadata");
  $app->{configuration} = $app->{hdf5}->group("/configuration");
  $app->{application}   = $app->{hdf5}->group("/application");
};

sub save_hdf5 {
  my ($app) = @_;

  my $spectrum = $::app->{base};
  my $fname = sprintf("%s.hdf", $spectrum->stub);
  my $fd = Wx::FileDialog->new( $app->{main}, "Save HDF5 file", cwd, $fname,
				"HDF5 files (*.hdf)|*.hdf|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving HDF5 file canceled.");
    return;
  };
  my $save_file = $fd->GetPath;
  #$::app->{hdf5}->DESTROY;
  move($::app->{hdf5file}, $save_file);
  $app->topof_hdf5($save_file);

  $app->indicate_state(1);
  $app->set_parameters;

  $app->{main}->status("HDF file saved as $save_file and will be updated automatically going forward.");
};


sub open_hdf5 {
  my ($app) = @_;

  my $fd = Wx::FileDialog->new( $::app->{main}, "Open HDF5 file", cwd, q{},
				"HDF5 files (*.hdf)|*.hdf|All files (*)|*",
				wxFD_OPEN|wxFD_CHANGE_DIR|wxFD_FILE_MUST_EXIST,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Opening HDF5 file canceled.");
    return;
  };
  my $file = $fd->GetPath;

  $app->init_hdf5('>'.$file);
  push_metadata($app);
  push_configuration($app);
};


sub push_metadata {
  my ($app) = @_;
  my $md = $app->{hdf5}->group('metadata');
  my %metadata = ();
  foreach my $fam ($md->groups) {
    $metadata{$fam} = {};
    foreach my $item ($md->group($fam)->attrs) {
      $metadata{$fam} -> {$item} = ($md->group($fam)->attrGet($item))[0];
    };
  };
  $app->{XDI}->place_metadata(\%metadata, $app);
};


## I'm not clear why this is necessary, but strings from the
## configuration group had strange characters appended to the ends.
## Passing them through quotes seems to fix the problem.
sub cval {
  my ($group, $name) = @_;
  my $val = ($group->attrGet($name))[0];
  $val = "$val";
  return $val;
};

sub push_configuration {
  my ($app) = @_;
  my $co = $app->{hdf5}->group('configuration');

  $app->{base}->$_($co->attrGet($_)) foreach (qw(color energycounterwidth gaussian_kernel imagescale outimage
						 polyfill_gaps polyfill_order splot_palette_name terminal
						 tiffcounter xdi_metadata_file));

  ##       Files
  #$app->{Files}->{stub}             -> SetValue(($co->attrGet('stub'))[0]);
  $app->{Files}->{stub}             -> SetValue(cval($co, "stub"));
  $app->{Files}->{element}          -> SetStringSelection(cval($co, 'element'));
  $app->{Files}->{line}             -> SetStringSelection(cval($co, 'line'));
  $app->{Files}->{scan_dir}         -> SetValue(cval($co, 'scan_folder'));
  $app->{Files}->{image_dir}        -> SetValue(cval($co, "image_folder"));

  #$app->{Files}->{scan_template}    -> SetValue(($co->attrGet('scan_template'))[0]);
  #$app->{Files}->{elastic_template} -> SetValue(($co->attrGet('elastic_template'))[0]);
  $app->{Files}->{scan_template}    -> SetValue(cval($co, 'scan_template'));
  $app->{Files}->{elastic_template} -> SetValue(cval($co, 'elastic_template'));
  $app->{Files}->{image_template}   -> SetValue(cval($co, 'image_template'));
  $app->{Files}->{div10}            -> SetValue(cval($co, 'div10'));

  ##       Mask
  $app->{Mask}->{rangemin}          -> SetValue(cval($co, 'width_min'));
  $app->{Mask}->{rangemax}          -> SetValue(cval($co, 'width_max'));
  $app->{Mask}->{badvalue}          -> SetValue(cval($co, 'bad_pixel_value'));
  $app->{Mask}->{weakvalue}         -> SetValue(cval($co, 'weak_pixel_value'));
  $app->{Mask}->{exponentvalue}     -> SetValue(cval($co, 'exponent'));
  $app->{Mask}->{gaussianvalue}     -> SetValue(cval($co, 'gaussian_blur_value'));
  $app->{Mask}->{shieldvalue}       -> SetValue(cval($co, 'shield'));
  $app->{Mask}->{socialvalue}       -> SetValue(cval($co, 'social_pixel_value'));
  $app->{Mask}->{socialvertical}    -> SetValue(cval($co, 'vertical'));
  $app->{Mask}->{lonelyvalue}       -> SetValue(cval($co, 'lonely_pixel_value'));
  # $app->{Mask}->{multiplyvalue}    -> GetValue(cval($co, 'scalemask'));
  $app->{Mask}->{arealvalue}        -> SetValue(cval($co, 'radius'));

  $app->set_parameters;
};
