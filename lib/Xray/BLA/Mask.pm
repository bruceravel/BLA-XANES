package Xray::BLA::Mask;

=for Copyright
 .
 Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf.
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

use Moose::Role;
use PDL::Core qw(pdl ones zeros);
use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);
use PDL::IO::Dumper;
use PDL::Image2D;
use PDL::Fit::Polynomial qw(fitpoly1d);

use File::Basename;
use List::MoreUtils qw(onlyidx);

sub mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{elastic}  ||= q{};
  $args{unity}    ||= 0;
  $args{pass}     ||= 0;
  $args{vertical} ||= 0;
  $args{use}        = 'file' if ref($args{use}) !~ m{ARRAY};
  $args{save}     ||= 0;
  $args{verbose}  ||= 0;
  $args{animate}  ||= 0;
  $args{plot}     ||= 0;
  $args{write}      = 0;
  $args{write}      = 1 if ($args{animate} or $args{save});
  local $|=1;

  $self->bad_pixel_mask(PDL::null);
  $self->npixels(0);

  my $ret = $self->check($args{elastic});
  if ($ret->status == 0) {
    die $self->report($ret->message, 'bold red');
  };

  ## import elastic image and store basic properties
  my @out = ();
  $out[0] = ($args{write}) ? $self->mask_file("0", $self->outimage) : 0;
  $args{write}   = $out[0];
  $args{verbose} = $args{verbose};
  $args{unity}   = 0;
  #$self->do_step('import_elastic_image', %args);

  if ($args{plot}) {
    print $self->report("Plotting measured image", 'cyan');
    my $save = $self->prompt;
    $self->prompt('        Hit return to plot the first step>');
    my $cbm = int($self->elastic_image->max);
    if ($cbm < 1) {
      $cbm = 1;
    } elsif ($cbm > $self->bad_pixel_value/$self->imagescale) {
      $cbm = $self->bad_pixel_value/$self->imagescale;
    };
    $self->cbmax($cbm);
    $self->plot_mask;
    $self->pause(-1);
    $self->prompt($save);
  };

  my $i=0;
  foreach my $st (@{$self->steps}) {
    my $set_npixels = ($st eq $self->steps->[-1]) ? 1 : 0;

    my @args = split(" ", $st);

    push @out, ($args{write}) ? $self->mask_file(++$i, $self->outimage) : 0;
    $args{write}   = $out[-1];
    $args{verbose} = $args{verbose};
    $args{unity}   = $set_npixels;

  STEPS: {
      ($args[0] eq 'bad') and do {
	$self->bad_pixel_value($args[1]);
	$self->weak_pixel_value($args[3]);
	$self->do_step('bad_pixels', %args);
	last STEPS;
      };

      ($args[0] eq 'multiply') and do  {
	$self->scalemask($args[2]);
	$self->do_step('multiply', %args);
	last STEPS;
      };

      ($args[0] eq 'areal') and do  {
	$self->operation($args[1]);
	$self->radius($args[3]);
	$self->do_step('areal', %args);
	last STEPS;
      };

      ($args[0] eq 'lonely') and do  {
	$self->lonely_pixel_value($args[1]);
	$self->do_step('lonely_pixels', %args);
	last STEPS;
      };

      ($args[0] eq 'social') and do  {
	$self->social_pixel_value($args[1]);
	$args[2] = (defined($args[2]) and ($args[2] eq 'vertical'));
	$self->vertical($args[2]);
	$self->do_step('social_pixels', %args);
	last STEPS;
      };

      ($args[0] eq 'gaussian') and do  {
	$self->gaussian_blur_value($args[1]);
	$self->do_step('gaussian_blur', %args);
	last STEPS;
      };

      ($args[0] eq 'polyfill') and do  {
	$self->do_step('poly_fill', %args);
	last STEPS;
      };

      ($args[0] eq 'entire') and do {
	$self->do_step('entire_image', %args);
	last STEPS;
      };

      ($args[0] eq 'aggregate') and do {
	$self->do_step('andaggregate', %args);
	last STEPS;
      };

      ($args[0] eq 'map') and do {
	$self->deltae($args[1]);
	$self->do_step('mapmask', %args);
	last STEPS;
      };

      ($args[0] eq 'andmask') and do {
	$self->do_step('andmask', %args);
	last STEPS;
      };

      ($args[0] eq 'useshield') and do {
	$self->shield($args[1]);
	$args{save_shield} = ($self->ui eq 'cli') ? 1 : 0;
	$self->do_step('useshield', %args);
	last STEPS;
      };

      print $self->report("I don't know what to do with \"$st\"", 'bold red');
    };
  };

  ## bad pixels may have been turned back on in the social, areal, or entire pass, so turn them off again
  $self->remove_bad_pixels;

  ## construct an animated gif of the mask building process
  if ($args{animate}) {		# currently disabled
    my $fname = $self->animate('anim', @out);
    print $self->report("Wrote $fname", 'yellow'), "\n" if $args{verbose};
  };
  if ($args{save}) {
    my $fname = $self->mask_file("mask", $self->outimage);
    $self->elastic_image->wim($fname);
    print $self->report("Saved mask to $fname", 'yellow'), "\n" if $args{verbose};
  };
  unlink $_ foreach @out;

};



##################################################################################
## mask creation utilities
##################################################################################

sub check {
  my ($self, $elastic) = @_;

  my $ret = Xray::BLA::Return->new;
  
  ## does elastic file exist?
  $elastic ||= $self->file_template($self->elastic_file_template);
  ##$elastic ||= join("_", $self->stub, 'elastic', $self->energy, $self->tiffcounter).'.tif';
  $self->elastic_file(File::Spec->catfile($self->tiffolder, $elastic));
  if (not -e $self->elastic_file) {
    $ret->message("Elastic image file \"".$self->elastic_file."\" does not exist");
    $ret->status(0);
    return $ret;
  };
  if (not -r $self->elastic_file) {
    $ret->message("Elastic image file \"".$self->elastic_file."\" cannot be read");
    $ret->status(0);
    return $ret;
  };

  ## does scan file exist?
  if (not $self->noscan) {
    my $sf = $self->check_scan;
    if (not $sf->is_ok) {
      $ret->status($sf->status);
      $ret->message($sf->message);
    };
  };
  $self->elastic_image($self->Read($self->elastic_file));

  return $ret;
};

sub check_scan {
  my ($self) = @_;
  my $ret = Xray::BLA::Return->new;
  if ($self->noscan) {
    $ret->status(1);
    $ret->message("This measurement does not use a scan file");
    return $ret;
  } else {
    my $scanfile = File::Spec->catfile($self->scanfolder, $self->file_template($self->scan_file_template));
    $self->scanfile($scanfile);
    if (not -e $scanfile) {
      $ret->message("Scan file \"$scanfile\" does not exist");
      $ret->status(0);
      return $ret;
    };
    if (not -r $scanfile) {
      $ret->message("Scan file \"$scanfile\" cannot be read");
      $ret->status(0);
      return $ret;
    };
  };
  $ret->status(1);
  $ret->message("Scan file ok");
  return $ret;
};

sub remove_bad_pixels {
  my ($self) = @_;
  $self->elastic_image->inplace->mult(1-$self->bad_pixel_mask,0);
};


## See Xray::BLA::Mask for the steps
sub do_step {
  my ($self, $step, @args) = @_;
  my %args = @args;
  $step = 'poly_fill' if $step eq 'polyfill';

  my $saved_image = $self->elastic_image->copy;
  my $ret = $self->$step(\%args);
  if (($ret->status == 0) and ($self->ui eq 'wx')) {
    $self->elastic_image($saved_image);
    return 0;
  } elsif ($ret->status == 0) {
    print "oops!\n";
    die $self->report($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $args{verbose};
  };
  $self->remove_bad_pixels;
  ## wim: see PDL::IO::Pic
  $self->elastic_image->wim($args{write}) if $args{write};
  $self->eimax($self->elastic_image->flat->max);
  $self->npixels($ret->status) if $args{unity};

  if ($args{plot}) {
    my $save = $self->prompt;
    $self->prompt('        Hit return to plot the next step>');
    my $cbm = int($self->elastic_image->max);
    if ($cbm < 1) {
      $cbm = 1;
    } elsif ($cbm > $self->bad_pixel_value/$self->imagescale) {
      $cbm = $self->bad_pixel_value/$self->imagescale;
    };
    $self->cbmax($cbm);# if $step =~ m{social};
    $self->plot_mask;
    $self->pause(-1);
    $self->prompt($save);
  };

  undef $ret;
  return 1;
};


##################################################################################
## mask creation steps

sub import_elastic_image {
  my ($self, $rargs) = @_;
  my %args = %$rargs;

  my $ret = Xray::BLA::Return->new;

  my ($c, $r) = $self->elastic_image->dims;
  $self->columns($c);
  $self->rows($r);
  my $str = $self->report("\nProcessing ".$self->elastic_file, 'yellow');
  $str   .= sprintf "\t%d columns, %d rows, %d total pixels\n",
    $self->columns, $self->rows, $self->columns*$self->rows;
  $ret->message($str);
  return $ret;
};



sub bad_pixels {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei     = $self->elastic_image;
  my ($w,$h) = $self->elastic_image->dims;
  my $bpv    = $self->bad_pixel_value;
  my $wpv    = $self->weak_pixel_value;

  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  my $bad  = $ei->gt($bpv,0);	# mask of bad pixels

  foreach my $spot (@{$self->spots}) {
    my $e = $spot->[0];
    next if $e =~ m{\A\#};
    my $doit = 0;
    if ($e =~ m{\+}) {
      $doit = 1 if ($self->energy >= substr($e, 0, -1));
    } elsif ($e =~ m{\-}) {
      my ($emin, $emax) = split(/\-/, $e);
      $doit = 1 if (($self->energy >= $emin) and ($self->energy <= $emax));
    } else {
      $doit = 1 if ($self->energy == $e);
    };
    if ($doit) {
      my $toss = PDL::Basic::rvals($ei->dims, {Centre=>[$spot->[1],$spot->[2]]})->inplace->lt($spot->[3],0);
      $bad += $toss;
    };
  };
  $bad->inplace->gt(0,0);	# in case of overlapping circles....
  if ($self->width_min > 0) {
    $bad->(0:$self->width_min) .= 1;
  };
  if ($self->width_max < $w-1) {
    $bad->($self->width_max:$w-1) .= 1;
  };

  my $weak = $ei->lt($wpv,0);	# mask of weak pixels
  $self->nbad($bad->sum);
  $ei  = $ei * (1-$bad) * (1-$weak); # remove bad and weak pixels
  $on  = $ei->gt(0,0)->sum;
  $off = $ei->eq(0,0)->sum;
  $self->elastic_image($ei);
  $self->bad_pixel_mask($bad);

  my $str = $self->report("Bad/weak step", 'cyan');
  $str   .= sprintf "\tRemoved %d bad pixels and %d weak pixels\n", $self->nbad, $weak->sum;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $ret->status($ei->gt(0,0)->sum);
  $ret->message($str);
  return $ret;
};

sub multiply {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  $self->elastic_image->inplace->mult($self->scalemask, 0);

  my $str = $self->report("Multiply image by ".$self->scalemask, 'cyan');
  $ret->status($self->elastic_image->gt(0,0)->sum);
  $ret->message($str);
  return $ret;
};

sub andaggregate {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;
  if ((not defined($args{aggregate})) or
      (ref($args{aggregate}) !~ m{BLA}) or
      ($args{aggregate}->masktype ne 'aggregate')
     ) {
    $ret->status(0);
    $ret->message("No aggregate image supplied (perhaps you haven't created it yet...)");
  }

  ##$self->elastic_image->wim('foo.tif');
  #Xray::BLA->trace;
  $self->elastic_image -> inplace -> mult($args{aggregate}->elastic_image, 0);
  my $str = $self->report("Multiply by aggregate mask", 'cyan');
  $ret->status($self->elastic_image->gt(0,0)->sum);
  $ret->message($str);
  return $ret;
};

sub entire_image {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  $self->elastic_image(ones($self->elastic_image->dims));
  my $str = $self->report("Using entire image", 'cyan');
  $ret->status($self->elastic_image->gt(0,0)->sum);
  $ret->message($str);
  return $ret;
};

sub andmask {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  $self->elastic_image->inplace->gt(0,0);
  $self->npixels($self->elastic_image->sum);
  my $str = $self->report("Making AND mask", 'cyan');
  $ret->status($self->npixels);
  $ret->message($str);
  return $ret;
};

sub useshield {
  my ($self, $rargs) = @_;
  if ($rargs->{use} eq 'file') {
    return $self->useshield_from_files($rargs);
  } else {
    return $self->useshield_from_pdls($rargs);
  };
};

sub useshield_from_files {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;
  my $shield = zeros($self->elastic_image->dims);
  my $prevfile = $self->mask_file('previousshield', 'gif');
  my ($mask, $maskfile);
  my $pdl;
  if ($prevfile) {
    my $prev = rim($prevfile);
    my $i = onlyidx {$_ == $self->energy} @{$self->elastic_energies};
    $pdl = zeros($self->elastic_image->dims);
    if ($i > $self->shield) {
      my ($thise, $olde) = ($self->energy, $self->elastic_energies->[$i-$self->shield+1]);
      $thise = sprintf("%3.3d", $thise) if $thise < 1000;
      $olde  = sprintf("%3.3d", $olde)  if $olde  < 1000;

      $maskfile = $self->mask_file('mask', 'gif');
      #print '>>>', join("|", $thise,$olde,$maskfile), $/;
      my ($base, $path) = fileparse($maskfile);
      $base =~ s{$thise}{$olde};
      $maskfile = File::Spec->catfile($path, $base);
      #print '>>>', join("|", $thise,$olde,$maskfile), $/;
      $mask = rim($maskfile);
      $pdl = $prev + $mask;
      my $kernel = ones(2,2);
      my $smoothed = $pdl->gt(0,0)->or2( $pdl->conv2d($kernel, {Boundary => 'Truncate'})->ge(2,0), 0 );
      $pdl = $smoothed;
    };
    $shield = $pdl;
  };

  my $fname;
  if ($args{save_shield}) {
    $fname = $self->mask_file("shield", $self->outimage);
    $shield->wim($fname);
  };
  $shield -> inplace -> eq(0,0); # invert the shield; 0-->1 and 1-->0
  $self->elastic_image->inplace->mult($shield,0);
  $self->npixels($self->elastic_image->sum);
  my $str;
  if (ref($mask) =~ m{PDL}) {
    $str = $self->report("Applying shield (".basename($prevfile)." + ".basename($maskfile).")", 'cyan');
  } else {
    $str = $self->report("Emission energy low, no shield", 'cyan');
  };
  my $on = $self->elastic_image->sum;
  $str .= "\t$on illuminated pixels\n";
  $str .= "\tWrote shield file, $fname\n" if ($args{save_shield});
  $ret->status($self->npixels);
  $ret->message($str);
  return $ret;
};

## $rargs->{use} is an array of 2 PDL, 0 is the PDL for the previous
## elastic energy, 1 is the PDL for <shield> elastic energies back
sub useshield_from_pdls {
  my ($self, $rargs) = @_;
  my $ret = Xray::BLA::Return->new;
  my $shield = zeros($self->elastic_image->dims);
  my $prevshield = zeros($self->elastic_image->dims);
  my $oldmask = zeros($self->elastic_image->dims);

  $prevshield = $rargs->{use}->[0]->shield_image  if UNIVERSAL::isa($rargs->{use}->[0], 'PDL');
  $oldmask    = $rargs->{use}->[1]->elastic_image if UNIVERSAL::isa($rargs->{use}->[1], 'PDL');

  if (not UNIVERSAL::isa($rargs->{use}->[0], 'PDL') or not UNIVERSAL::isa($rargs->{use}->[1], 'PDL')) {
    $self->shield_image(zeros($self->elastic_image->dims));
    return $ret;
  };
  ##print $rargs->{use}->[0]->energy, " ", $rargs->{use}->[1]->energy, $/;

  my $pdl = $prevshield + $oldmask;
  my $kernel = ones(2,2);
  my $smoothed = $pdl->gt(0,0)->or2( $pdl->conv2d($kernel, {Boundary => 'Truncate'})->ge(2,0), 0 );
  $pdl = $smoothed;
  $self->shield_image($pdl);
  $self->elastic_image->inplace->mult($shield->eq(0,0),0);
  $self->npixels($self->elastic_image->sum);
  my $str = $self->report("Applying shield (shield(".$rargs->{use}->[0]->energy.") + mask(".$rargs->{use}->[1]->energy."))", 'cyan');
  my $on = $self->elastic_image->sum;
  $str .= "\t$on illuminated pixels\n";
  $ret->status($self->npixels);
  $ret->message($str);
  return $ret;
};

sub lonely_pixels {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $lpv   = $self->lonely_pixel_value;


  my ($h,$w) = $ei->dims;
  my $onoff = $ei->gt(0,0);
  my $before = $onoff->sum;
  ## this simple convolution will measure the number of neighbors
  my $smoothed = $onoff->conv2d(ones(3,3), {Boundary => 'Truncate'});

  ## set pixels smaller than $lpv to 0
  $ei->inplace->mult(1-$smoothed->le($lpv,0),0);
  $self->elastic_image($ei);

  my $onval  = $ei->gt(0,0)->sum;
  my $offval = $h*$w-$onval;

  my $str = $self->report("Lonely pixel step", 'cyan');
  $str   .= sprintf "\tRemoved %d lonely pixels\n", $before - $onval;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $onval, $offval, $onval+$offval;
  $ret->status($ei->gt(0,0)->sum);
  $ret->message($str);
  return $ret;
};

sub social_pixels {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  my $spv   = $self->social_pixel_value;

  my $onoff = $self->elastic_image->gt(0,0);
  my $before = $onoff->sum;
  my $kernel = ones(3,3);
  if ($args{vertical}) {
    $kernel->(0,:) .= 0.00001;
    $kernel->(2,:) .= 0.00001;
    ## rotate this matrix if the shadows are not perpendicular
  };
  my $smoothed = $onoff->conv2d($kernel, {Boundary => 'Truncate'});

  my ($h,$w) = $self->elastic_image->dims;
  my $on  = $smoothed->ge($spv,0);
  my $onval  = $on->sum;
  my $offval = $h*$w-$onval;
  $self->elastic_image($self->elastic_image->or2($on,0));

  my $text = $args{pass} ? " (pass ".$args{pass}.")" : q{};
  my $str = $self->report("Social pixel step$text", 'cyan');
  $str   .= sprintf "\tAdded %d social pixels\n", $onval-$before;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $onval, $offval, $onval+$offval;
  $ret->status($onval);
  $ret->message($str);
  return $ret;
};


## https://en.wikipedia.org/wiki/Kernel_%28image_processing%29
sub gaussian_blur {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  my $gbv   = $self->gaussian_blur_value;
  
  my $onoff = $self->elastic_image->gt(0,0);
  my $before = $onoff->sum;
  my $kernel = pdl( [ [1./16, 2./16, 1./16], [2./16, 4./16, 2./16], [1./16, 2./16, 1./16] ] );
  my $blurred = $self->elastic_image->conv2d($kernel, {Boundary => 'Truncate'});

  my ($h,$w) = $self->elastic_image->dims;
  my $on  = $blurred->ge($gbv,0);
  my $onval  = $on->sum;
  my $offval = $h*$w-$onval;
  $self->elastic_image($on);

  my $text = $args{pass} ? " (pass ".$args{pass}.")" : q{};
  my $str = $self->report("Gaussian blur step$text", 'cyan');
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $onval, $offval, $onval+$offval;
  $ret->status($onval);
  $ret->message($str);
  return $ret;
};

sub poly_fill {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;
  my $ei  = $self->elastic_image;
  my ($w,$h) = $self->elastic_image->dims;

  my @x = ();
  my @allx = ();
  my @y = ();
  my $count = 0;
  #my $ydata;

  #$ei=$ei->xchg(0,1);
  #$self->elastic_image($ei);
  #($w,$h) = ($h,$w);

  foreach my $col (0 .. $w-1) {
    my $this = $ei->($col,:)->which;
    next if not $this->dim(0);
    push @allx, $col;
    next if $this->dim(0) == 1;
    next if $this->at(0) == $this->at(-1);

    ## looking for gaps left to right makes sense in that energy disperses left to right.
    #last if (($count > 2) and ($col - $x[$count-2] > 30));
    ## 30 is bigger than any of the Soller slit gaps
    ## this simple test will fail if the spot is within the curvature of the mask

    push @x, $col;
    push @y, $this->(pdl(0,$this->dim(0)-1));
    #if (defined($ydata)) {
    #  $ydata = $ydata->glue(1, $this->(pdl(0,$this->dim(0)-1))); # append the pdl with the first and last from $this
    #} else {
    #  $ydata = $this->(pdl(0,$this->dim(0)-1));
    #};
    ++$count;
  };
  my $xdata = pdl(\@x);
  my $ydata = pdl(\@y)->xchg(0,1);
  #$ydata=$ydata->xchg(0,1);

  #use Data::Dump::Color;
  #dd \@x, \@y;
  #print $xdata, $/;
  #print $ydata, $/;

  my $on = zeros($ei->dims);
  if ($args{plot}) {
    foreach my $i (0..$#x-1) {
      $on->set($x[$i], $y[$i]->(0)->sclr, 1);
      $on->set($x[$i], $y[$i]->(1)->sclr, 1);
    };
    $self->elastic_image($on);
    my $save = $self->prompt;
    $self->prompt('        Boundaries: Hit return to plot the next step>');
    $self->plot_mask;
    $self->pause(-1);
    $self->prompt($save);
  };

  my $order = 6;
  my ($yfit1, $coeffs1) = fitpoly1d($xdata, $ydata(:,0), $order);
  my ($yfit2, $coeffs2) = fitpoly1d($xdata, $ydata(:,1), $order);

  if ($args{plot}) {
    $on = zeros($ei->dims);
    foreach my $i (@x) {		    # leave  Soller slit gaps
      my $xpow = pdl( map {$i ** $_} (0 .. $order-1) ); # powers of X for polynomial
      my $y1 = $coeffs1 * $xpow;
      my $y2 = $coeffs2 * $xpow;
      my $yy1 = int($y1->sum+0.5);
      my $yy2 = int($y2->sum+0.5);
      $on->set($i, $yy1, 1) if ($yy1<195 and $yy1>0);
      $on->set($i, $yy2, 1) if ($yy2<195 and $yy2>0);
    };
    $self->elastic_image($on);
    my $save = $self->prompt;
    $self->prompt('        Polynomial fits: Hit return to plot the next step>');
    $self->plot_mask;
    $self->pause(-1);
    $self->prompt($save);
  };

  foreach my $i (reverse(1 .. $#x-1)) {
    if ($x[$i] - $x[$i-1] == 2) {      # remove gaps which are 1 pixel wide
      splice(@x, $i-1, 1, $x[$i-1]+1); # by splicing in the missing number
    };
  };
  #foreach my $i ($x[0]..$x[-1]) {  # remove Soller slit gaps
  foreach my $i (@x) {		    # leave  Soller slit gaps
    my $xpow = pdl( map {$i ** $_} (0 .. $order-1) ); # powers of X for polynomial
    my $y1 = $coeffs1 * $xpow;
    my $y2 = $coeffs2 * $xpow;
    foreach my $y (int($y1->sum+0.5) .. int($y2->sum+0.5)) {
      $on->set($i, $y, 1) if ($y<195 and $y>0);
    };
  };

  #$on=$on->xchg(0,1);
  $self->elastic_image($on);

  $ret->status(1);
  my $str = $self->report("polyfill step", 'cyan');
  my $onval = $on->sum;
  my $offval = $h*$w-$onval;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $onval, $offval, $onval+$offval;
  $ret->message($str);

  return $ret;
};

## spot removal
# $k = pdl([1,1,1],[1,1,1],[1,1,1]);
# $sm = $a->convolveND($k);
# $sm->inplace->gt(7,0)

sub mapmask {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  my $maskfile = $self->mask_file("maskmap", $self->outimage);
  if (not -e $maskfile) {
    $ret->status(0);
    $ret->message("The energy map file $maskfile does not exist.");
    return $ret
  };
  if (not -r $maskfile) {
    $ret->status(0);
    $ret->message("The energy map file $maskfile cannot be read.");
    return $ret
  };
  my $image = frestore($maskfile);
  $self -> elastic_image($image);
  $self -> elastic_image->inplace->minus($self->energy,0);
  $self -> elastic_image->inplace->abs;
  $self -> elastic_image->inplace->lt($self->deltae,0);

  my $on  = $self->elastic_image->flat->sumover->sclr;
  my $off = $self->columns*$self->rows - $on;
  my $str = $self->report("Energy map step", 'cyan');
  $str   .= sprintf "\tUsing pixels within %.2f eV of %.1f eV\n", $self->deltae, $self->energy;
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;

  $ret->status($on);
  $ret->message($str);
  return $ret;

};

sub areal {
  my ($self, $rargs) = @_;
  my %args = %$rargs;
  my $ret = Xray::BLA::Return->new;

  $self->remove_bad_pixels;
  my $ei    = $self->elastic_image;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my @list = ();

  my ($h,$w) = $ei->dims;

  my $before = $ei->gt(0,0)->sum;
  my $radius = $self->radius;
  my $kernel = ones(2*$radius+1,2*$radius+1) / (2*$radius+1)**2;
  my $smoothed = $ei->conv2d($kernel, {Boundary => 'Truncate'});
  #$smoothed = $smoothed->gt(1,0);
  my $on = $smoothed->gt(0,0)->sum;
  my $off = $h*$w - $on;

  $self->elastic_image($smoothed);

  my $str = $self->report("Areal ".$self->operation." step", 'cyan');
  my $n = 2*$self->radius+1;
  $str   .= "\tSet each pixel to the ".$self->operation." value of a ${n}x$n square centered at that pixel\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $ret->status($on);
  $ret->message($str);
  return $ret;
};


sub aggregate {
  my ($self) = @_;
  my $save = $self->energy;
  $self->elastic_image(PDL::null);
  my $sum;
  my $i = 0;
  foreach my $e (@{$self->elastic_energies}) {
    $self -> energy($e);
    my $file = ($#{$self->elastic_file_list} > -1) ? $self->elastic_file_list->[$i] : q{};
    my $ret = $self->check($file);
    if ($ret->status == 0) {
      die $self->report($ret->message, 'bold red');
    };
    $self->do_step('bad_pixels', write=>0, verbose=>0, unity=>0);
    if (not defined($sum)) {
      $sum = $self->elastic_image;
    } else {
      $sum += $self->elastic_image;
    };
    ++$i;
  };

  $self->masktype('aggregate');
  $self->elastic_image($sum);

  $self->energy($save);
};


1;

=head1 NAME

Xray::BLA::Mask - Role containing mask creation steps

=head1 VERSION

See L<Xray::BLA>

=head1 METHODS

=head2 General methods

=over 4

=item C<mask>

Create a mask from the elastic image measured at the energy given by
C<energy>.

  $spectrum->mask(@args);

where the arguments are given using fat commas, as in C<verbose=>0,
save=>0, animate=>0>.

The arguments are:

=over 4

=item C<verbose>

When true, this causes messages to be printed to standard output with
information about each stage of mask creation.  Only used in CLI mode.

=item C<save>

When true, this causes an image file to be saved at each stage of
processing the mask.  Usually only used in CLI mode.

=item C<animate>

This causes a properly scaled animation to be written showing the
stages of mask creation.

=item C<elastic>

Explicitly specify a file to use as the elastic image.  In CLI mode,
this is usually determined algorithmicly, but in Metis it is taken
from one of the image lists on the Files page.

=item C<unity>

??

=item C<pass>

This is a counter for multiple passes of the C<social> step.

=item C<vertical>

When true, this tells the C<social> step to only consider pixels
directly above and below.

=item C<plot>

When true, this will generate a plot at each stage of mask creation
along with a pause for viewing it.  This is only used in CLI mode.

=item C<write>

When given a filename, an image file will be written at the end of a
mask creation step.  When given a false value, the image file will be
written.

=back

These output image files are gif on linux and tif on Windows.

This method is a wrapper around the contents of the
C<steps> attribute.  Each entry in C<steps> will be parsed and
executed in sequence.

=item C<check>

Verify that the elastic image file exists, can be read, and be
imported as an image file.  This sets the C<elastic_file> and
C<elastic_image> attributes.

=item C<remove_bad_pixels>

This removes the bad pixels from the map using the
C<bad_pixel_mask> attribute.  Some of the steps, C<areal> for example,
can reinsert a bad pixel, so it is necessary to follow each step with
this method to ensure that the bad pixels are not used in HERFD
processing.

=item C<do_step>

A wrapper around the various mask processing steps.  This calls the
various steps, manages screen messages, sets some attributes, manages
plotting in CLI mode, and manages saving images of steps in the mask
creation process when in CLI mode.  In Metis, this is usually called
directly without calling the C<mask> method.

=back

=head2 Methods for the steps of mask creation

=over 4

=item C<bad_pixels>

Remove pixels that are larger than the value of the C<bad_pixel_value>
attribute and smaller than the C<weak_pixel_value> attribute.  This
must be the first step in mask processing.  This also sets the
C<bad_pixel_mask> attribute, which identifies the pixels marked as bad
pixels.

Controlling attributes: C<bad_pixel_value>, C<weak_pixel_value>

=item C<gaussian_blur>

Apply an approximate Gaussian blur filter to the image.  Set all
pixels above a threshold value to 1, setting all below that value to
0.  This is a simple convolution with this kernel:

    1   / 1 2 1 \
  ---- (  2 4 2  )
   16   \ 1 2 1 /

The size of the threshold depends on the intensity of the relevant
part of the image.  Very bright, spurious spots will pass through this
filter.

Controlling attribute: C<gaussian_blur_value>

=item C<useshield>

Construct a shield used to mask out a region of the elastic image
associated with fluorescence or some other source of signal.

Shields are constructed sequentially.  The first N steps do not have a
shield -- more specifically, the shield is empty.  The next shield
uses the mask from N steps prior to block out this signal.  The
following shield adds the mask from N steps back to the shield of
the previous step.  Subsequent steps accumulate the masks from N
steps back, adding them to their shields.

All pixels under the shield are then set to 0.

Controlling attribute: C<shield>

=item C<polyfill>

After the Gaussian blur or other filtering step to remove all of the
outlying pixels, the top-most and bottom-most pixels in each column
are noted.  Two polynomials are fit to this collection of points, one
to the top set and one to the bottom set.  The pixels between the two
polynomials are turned on, yielding the final mask.

Controlling attributes: none.

=item C<lonely_pixels>

Remove illuminated pixels which are not surrounded by enough other
illuminated pixels.

Controlling attribute: C<lonely_pixel_value>

=item C<social_pixels>

Include dark pixels which are surrounded by enough illuminated pixels.

Controlling attribute: C<social_pixel_value>

=item C<areal>

At each point in the mask, assign its value to the median or mean
value of a square centered on that point.  The size of the square is
determined by the value of the C<radius> attribute.

The median operation is not currently supported.

Controlling attributes: C<operation>, C<radius>

=item C<multiply>

Multiply the entire image by a scaling factor.

Controlling attribute: C<scalemask>

=item C<entire_image>

Set every pixel in the mask to 1.  This makes the "HERFD" using the
entire image at each energy point.  This is used for testing and
demonstration purposes and is not actually a useful step for making
high energy resolution data.

Controlling attributes: none

=item C<mapmask>

(coming soon)

=item C<andmask>

This is the final step in mask creation.  It sets all non-zero pixels
to 1 so that the mask can be directly multiplied by images at each
data point in a HERFD scan.

Controlling attributes: none

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://github.com/bruceravel/BLA-XANES>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
