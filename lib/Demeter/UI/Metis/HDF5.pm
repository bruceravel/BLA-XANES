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
use File::Basename;
use File::Copy;
use List::MoreUtils qw(any);
use PDL::IO::HDF5;
use Wx qw(:everything);

sub init_hdf5 {
  my ($app, $hdfile) = @_;
  ## --- make an HDF5 file and begin to populate it
  #my $hdfile = File::Spec->catfile($app->{base}->outfolder, "metis.mpj");
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
  $app->{scan}          = $app->{hdf5}->group("/scan") if ($app->{tool} !~ m{\A(?:xes|mask)\z});
  $app->{metadata}      = $app->{hdf5}->group("/metadata");
  $app->{configuration} = $app->{hdf5}->group("/configuration");
  $app->{application}   = $app->{hdf5}->group("/application");
};

sub save_hdf5 {
  my ($app) = @_;

  my $spectrum = $::app->{base};
  my $fname = sprintf("%s.mpj", $spectrum->stub);
  my $fd = Wx::FileDialog->new( $app->{main}, "Save Metis project file", cwd, $fname,
				"MPJ files (*.mpj)|*.mpj|All files (*)|*",
				wxFD_OVERWRITE_PROMPT|wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving Metis project file canceled.");
    return;
  };
  my $save_file = $fd->GetPath;
  #$::app->{hdf5}->DESTROY;
  $app->set_parameters;
  move($::app->{hdf5file}, $save_file);
  $app->topof_hdf5($save_file);

  $app->save_indicator(0);

  $app->{main}->status("Metis project file saved as $save_file.");
};


sub open_hdf5 {
  my ($app, $file) = @_;

  $app->{book}->SetSelection(0);
  $app->{Files}->{stub}->SetFocus;
  if ((not $file) or (not -e $file)) {
    my $fd = Wx::FileDialog->new( $::app->{main}, "Open Metis project file", cwd, q{},
				  "MPJ files (*.mpj)|*.mpj|All files (*)|*",
				  wxFD_OPEN|wxFD_CHANGE_DIR|wxFD_FILE_MUST_EXIST,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $::app->{main}->status("Opening Metis project file canceled.");
      return;
    };
    $file = $fd->GetPath;
  };

  my $start = DateTime->now( time_zone => 'floating' );
  $app->init_hdf5('>'.$file);
  push_metadata($app);
  push_configuration($app);
  push_steps_spots($app);

  $app->{Files}->{elastic_list}->Clear;
  push_elastic($app);

  $app->{Files}->{image_list}->Clear;
  push_images($app);

  $app->save_indicator(0);
  $app->{main}->status("Imported Metis project file $::hdf5file" .
		       $app->{base}->howlong($start, '.  That'));

  push_scan($app) if ($app->{tool} !~ m{\A(?:xes|mask)\z});
};


## I'm not clear why this is necessary, but strings from the
## configuration group had strange characters appended to the ends.
## Passing them through quotes seems to fix the problem.
sub attribute {
  my ($group, $name) = @_;
  my $val = ($group->attrGet($name))[0];
  $val = "$val";
  return $val;
};

sub push_metadata {
  my ($app) = @_;
  my $md = $app->{hdf5}->group('metadata');
  my %metadata = ();
  foreach my $fam ($md->groups) {
    $metadata{$fam} = {};
    foreach my $item ($md->group($fam)->attrs) {
      $metadata{$fam} -> {$item} = attribute($md->group($fam), $item);
    };
  };
  $app->{XDI}->place_metadata(\%metadata, $app);
};


sub push_configuration {
  my ($app) = @_;
  my $co = $app->{hdf5}->group('configuration');
  my @attributes = $co->attrs;
  $app->{tool} = attribute($co, "mode");

  $app->{base}->$_(attribute($co, $_)) foreach (qw(color energycounterwidth gaussian_kernel imagescale outimage
						   polyfill_gaps polyfill_order splot_palette_name terminal
						   tiffcounter xdi_metadata_file));
  $app->{base}->scanfile(attribute($co, 'scanfile')) if ($app->{tool} !~ m{\A(?:xes|mask)\z});;

  ##       Files
  $app->{Files}->{stub}             -> SetValue(attribute($co, "stub")               );
  $app->{Files}->{scan_dir}         -> SetValue(attribute($co, 'scan_folder')        );
  $app->{Files}->{image_dir}        -> SetValue(attribute($co, "image_folder")       );
  $app->{Files}->{scan_template}    -> SetValue(attribute($co, 'scan_template')      );
  $app->{Files}->{elastic_template} -> SetValue(attribute($co, 'elastic_template')   );
  $app->{Files}->{image_template}   -> SetValue(attribute($co, 'image_template')     );
  $app->{Files}->{div10}            -> SetValue(attribute($co, 'div10')              );
  $app->{Files}->{element}          -> SetStringSelection(attribute($co, 'element')  );
  $app->{Files}->{line}             -> SetStringSelection(attribute($co, 'line')     );

  ##       Mask
  $app->{Mask}->{rangemin}          -> SetValue(attribute($co, 'width_min')          );
  $app->{Mask}->{rangemax}          -> SetValue(attribute($co, 'width_max')          );
  $app->{Mask}->{badvalue}          -> SetValue(attribute($co, 'bad_pixel_value')    );
  $app->{Mask}->{weakvalue}         -> SetValue(attribute($co, 'weak_pixel_value')   );
  $app->{Mask}->{exponentvalue}     -> SetValue(attribute($co, 'exponent')           );
  $app->{Mask}->{gaussianvalue}     -> SetValue(attribute($co, 'gaussian_blur_value'));
  $app->{Mask}->{shieldvalue}       -> SetValue(attribute($co, 'shield')             );
  $app->{Mask}->{socialvalue}       -> SetValue(attribute($co, 'social_pixel_value') );
  $app->{Mask}->{socialvertical}    -> SetValue(attribute($co, 'vertical')           );
  $app->{Mask}->{lonelyvalue}       -> SetValue(attribute($co, 'lonely_pixel_value') );
  $app->{Mask}->{arealvalue}        -> SetValue(attribute($co, 'radius'));
  # $app->{Mask}->{multiplyvalue}    -> GetValue(attribute($co, 'scalemask')          );

  if ($app->{tool} ne 'mask') {
    if (any {$_ = 'energy'} @attributes) {
      $app->{Data}->{energy} = attribute($co, 'energy');
      $app->{Data}->{energylabel}->SetLabel('Current mask energy is '.attribute($co, 'energy'));
    };
  };

  $app->{Mask}->{stub}->SetLabel("Stub is ".attribute($co, "stub"));
  $app->set_parameters;
};

sub push_steps_spots {
  my ($app) = @_;
  my $co = $app->{hdf5}->group('configuration');
  my @datasets = $co->datasets;
  my ($steps, $spots);
  if (any {$_ eq 'steps'} @datasets) { # set steps list and enable widgets if present
    $steps = $co->dataset('steps')->get;
    $app->{Mask}->{steps_list}->Clear;
    foreach my $i (0 .. $steps->dim(1) - 1) {
      my $this = $steps->atstr($i);
      $app->{Mask}->{steps_list}->Append( "$this" );
    };
    $app->{Mask}->most(1);
    $app->{Mask}->{replot}->Enable(1);
    $app->{Mask}->{plotshield}->Enable(1);
    $app->{Mask}->{toggle}->Enable(1);

    if ($app->{tool} ne 'mask') {
      $app->{Data}->{stub}->SetLabel("Stub is ".attribute($co, "stub"));
      #$app->{Data}->{energylabel}->SetLabel("Current mask energy is ".$app->{Mask}->{energy}->GetStringSelection);
      #$app->{Data}->{energy} = $spectrum->energy;
      foreach my $k (qw(stub energylabel herfd mue xes xes_all reuse showmasks incident incident_label rixs rshowmasks rxes xshowmasks)) {
	$app->{Data}->{$k}->Enable(1);
      };
    };
  };
  if (any {$_ eq 'spots'} @datasets) { # set spots list if present
    $spots = $co->dataset('spots')->get;
    $app->{Mask}->{spots_list}->Clear;
    foreach my $i (0 .. $spots->dim(1) - 1) {
      my $this = $spots->atstr($i);
      $app->{Mask}->{spots_list}->Append( $this );
    };
  };

};

sub push_elastic {
  my ($app) = @_;
  my $el = $app->{hdf5}->group('elastic');
  my @groups = $el->groups;


  my $count = 0;
  foreach my $gp (sort @groups) {
    ++$count;
    if (not $count%5) {
      $app->{main}->status(sprintf("Preparing %s (%d of %d)", $gp, $count, $#groups),
			   'wait|nobuffer');
      $app->{main}->Refresh;
    };
    $app->{base}->push_elastic_energies($gp);
    $app->{bla_of}->{$gp} = $app->{base}->clone;
    $app->{bla_of}->{$gp}->elastic_file(attribute($el->group($gp), 'file'));
    $app->{bla_of}->{$gp}->energy($gp);
    #$app->{bla_of}->{$gp}->energy(attribute($el->group($gp), 'energy'));

    my @datasets = $el->group($gp)->datasets;
    $app->{bla_of}->{$gp}->raw_image($el->group($gp)->dataset('image')->get)     if any {$_ eq 'image'}  @datasets;
    $app->{bla_of}->{$gp}->shield_image($el->group($gp)->dataset('shield')->get) if any {$_ eq 'shield'} @datasets;
    if (any {$_ eq 'mask'}   @datasets) {
      $app->{bla_of}->{$gp}->elastic_image($el->group($gp)->dataset('mask')->get);
      $app->{bla_of}->{$gp}->npixels($app->{bla_of}->{$gp}->elastic_image->sum);
    };
    $app->{Files}->{elastic_list}->Append(basename($app->{bla_of}->{$gp}->elastic_file),0);
  };

  $app->{Mask}->{$_} -> Enable(1) foreach (qw(steps_list spots_list pluck restoresteps energy rangemin rangemax
					      do_bad badvalue badlabel weaklabel weakvalue exponentlabel exponentvalue energylabel
					      rangelabel rangemin rangeto rangemax energy stub)); #  rbox
  $app->{Mask}->{energy} -> Clear;
  $app->{Mask}->{energy} -> Append($_) foreach @{$app->{base}->elastic_energies};
  my $start = ($app->{tool} eq 'herfd') ? int(($#{$app->{base}->elastic_energies}+1)/2) : 0;
  $app->{Mask}->{energy} -> SetSelection($start);
  #$app->{Data}->{energy}  = $app->{bla_of}->{$groups[0]}->energy;

  $app->{main}->status("Imported elastic images from Metis project file.");
};


sub push_images {
  my ($app) = @_;
  my $im = $app->{hdf5}->group('images');
  my @datasets = $im->datasets;
  foreach my $dsname (sort @datasets) {
    my $ds = $im->dataset($dsname);
    my $fname = ($ds -> attrGet('file'))[0];
    $fname = "$fname";
    $app->{Files}->{image_list}->Append(basename($fname),$ds);
    $app->{Data}->{incident}->Append(basename($fname),$ds) if ($app->{tool} ne 'mask');
  };
  $app->{Data}->{incident}->SetSelection(0) if ($app->{tool} ne 'mask');
  $app->{main}->status("Imported measurements from Metis project file.");
};


sub push_scan {
  my ($app) = @_;
  my $sc = $app->{hdf5}->group('scan');
  my @attributes = $sc->attrs;
  if (any {$_ eq 'contents'} @attributes) {
    open(my $SCAN, '>', File::Spec->catfile($app->{base}->outfolder, "scanfile"));
    print $SCAN attribute($sc, 'contents');
    close $SCAN;
    $sc->attrSet(temporary=>File::Spec->catfile($app->{base}->outfolder, "scanfile"));
  };

};

1;
