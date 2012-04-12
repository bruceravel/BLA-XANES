package Xray::BLA;
use Xray::BLA::Return;
use Xray::BLA::Image;

use version;
our $VERSION = version->new('0.6');
use feature "switch";

use Moose;
use Moose::Util qw(apply_all_roles);
with 'Xray::BLA::Backend::Imager';
with 'Xray::BLA::Pause';
use MooseX::Aliases;
use Moose::Util::TypeConstraints;

use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);

use File::Copy;
use File::Path;
use File::Spec;
use Graphics::GnuplotIF;
use List::Util qw(sum max);
use List::MoreUtils qw(pairwise);
use Math::Round qw(round);
use Scalar::Util qw(looks_like_number);
use Term::Sk;
use Text::Template;
use Xray::Absorption;

use vars qw($XDI_exists);
$XDI_exists = eval "require Xray::XDI" || 0;

$ENV{TERM} = 'dumb' if not defined $ENV{TERM};
$ENV{TERM} = 'dumb' if ($ENV{TERM} =~ m{\A\s*\z});
eval 'use Term::ANSIColor ()';
eval { require Win32::Console::ANSI } if (($^O =~ /MSWin32/) and ($ENV{TERM} eq 'dumb'));

##with 'MooseX::MutatorAttributes';
##with 'MooseX::SetGet';		# this is mine....

has 'element'            => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "The two-letter symbol of the absorber element.");
has 'line'               => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "The Siegbahn or IUPAC symbol of the measured emission line.");

enum 'BlaTasks' => [qw(herfd rixs point map mask xes test list none)];
coerce 'BlaTasks',
  from 'Str',
  via { lc($_) };
has 'task'		 => (is => 'rw', isa => 'BlaTasks',  default => q{none},
			     documentation => "The data processing task as set by the calling program.");
has 'colored'		 => (is => 'rw', isa => 'Bool', default => 1,
			     documentation => "A flag for turning colored output on and off.");
has 'screen'		 => (is => 'rw', isa => 'Bool', default => 1,
			     documentation => "A flag indicating whether output is written to STDOUT.");

has 'stub'		 => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "The base of filenames from a measurement.");
has 'scanfile'		 => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "The name of the text file containing the scan data.");
has 'scanfolder'	 => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "The location on disk of the scan file.");
has 'tiffolder'		 => (is => 'rw', isa => 'Str', default => q{}, alias => 'tifffolder',
			     documentation => "The location on disk of the Pilatus images.");
has 'outfolder'		 => (is => 'rw', isa => 'Str', default => q{},
			     trigger => sub{my ($self, $new) = @_; mkpath($new) if not -d $new;},
			     documentation => "The location on disk to which processed data and images are written.");

has 'energy'	         => (is => 'rw', isa => 'Int', default => 0, alias => 'peak_energy',
			     documentation => "The specific emission energy at which to perform the calculation.");
has 'incident'	         => (is => 'rw', isa => 'Num', default => 0,,
			     documentation => "The specific incident energy at which to compute the emission spectrum.");
has 'nincident'	         => (is => 'rw', isa => 'Int', default => 0,,
			     documentation => "The data point index at which to compute the emission spectrum.");
has 'columns'            => (is => 'rw', isa => 'Int', default => 0, alias => 'width',
			     documentation => "The width of the images in pixels.");
has 'rows'               => (is => 'rw', isa => 'Int', default => 0, alias => 'height',
			     documentation => "The height of the images in pixels.");

has 'bad_pixel_value'	 => (is => 'rw', isa => 'Int', default => 400,
			     documentation => "The value above which a pixel is considered to be a bad pixel.");
has 'weak_pixel_value'	 => (is => 'rw', isa => 'Int', default => 3,
			     documentation => "The value below which a pixel is considered to contain a spurious signal.");
has 'lonely_pixel_value' => (is => 'rw', isa => 'Int', default => 3,
			     documentation => "The number of illuminated neighbors below which a pixel is considered isolated and should be removed from the mask.");
has 'social_pixel_value' => (is => 'rw', isa => 'Int', default => 2,
			     documentation => "The number of illuminated neighbors above which a pixel is considered as part of the mask.");
has 'npixels'            => (is => 'rw', isa => 'Int', default => 0,
			     documentation => "The number of illuminated pixels in the final mask.");
has 'nbad'               => (is => 'rw', isa => 'Int', default => 0,
			     documentation => "The number of bad pixels found in the elastic image.");

#has 'maskmode'           => (is => 'rw', isa => 'Int', default => 2, documentation => "<deprecated>");
has 'radius'             => (is => 'rw', isa => 'Int', default => 2,
			     documentation => "The radius used for the areal mean/median step of mask creation.");
has 'scalemask'          => (is => 'rw', isa => 'Num', default => 1,
			     documentation => "The value by which to multiply the mask during the multiplication step of mask creation.");

enum 'Xray::BLA::Projections' => ['median', 'mean'];
coerce 'Xray::BLA::Projections',
  from 'Str',
  via { lc($_) };
has 'operation'          => (is => 'rw', isa => 'Xray::BLA::Projections', default => q{median},
			     documentation => "The areal operation, either median or mean.");

has 'elastic_file'       => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "THe fully resolved file name containing the measured elastic image.");
has 'elastic_image'      => (is => 'rw', isa => 'PDL', default => sub {PDL::null},
			     documentation => "The PDL object containing the elastic image.");

has 'bad_pixel_list' => (
			 traits    => ['Array'],
			 is        => 'rw',
			 isa       => 'ArrayRef',
			 default   => sub { [] },
			 handles   => {
				       'push_bad_pixel_list'  => 'push',
				       'pop_bad_pixel_list'   => 'pop',
				       'clear_bad_pixel_list' => 'clear',
				      },
			 documentation => "An array reference containing the x,y coordinates of the bad pixels."
			);

has 'elastic_energies' => (
			   traits    => ['Array'],
			   is        => 'rw',
			   isa       => 'ArrayRef',
			   default   => sub { [] },
			   handles   => {
					 'push_elastic_energies'  => 'push',
					 'pop_elastic_energies'   => 'pop',
					 'clear_elastic_energies' => 'clear',
					},
			   documentation => "An array reference containing the energies at which elastic images were measured."
			  );
has 'elastic_file_list' => (
			    traits    => ['Array'],
			    is        => 'rw',
			    isa       => 'ArrayRef',
			    default   => sub { [] },
			    handles   => {
					  'push_elastic_file_list'  => 'push',
					  'pop_elastic_file_list'   => 'pop',
					  'clear_elastic_file_list' => 'clear',
					 },
			    documentation => "An array reference containing the fully resolved file names of the measured elastic images."
			   );
has 'elastic_image_list' => (
			     traits    => ['Array'],
			     is        => 'rw',
			     isa       => 'ArrayRef',
			     default   => sub { [] },
			     handles   => {
					   'push_elastic_image_list'  => 'push',
					   'pop_elastic_image_list'   => 'pop',
					   'clear_elastic_image_list' => 'clear',
					  },
			    documentation => "An array reference containing the PDL objects of the measured elastic images."
			    );

has 'herfd_file_list' => (
			  traits    => ['Array'],
			  is        => 'rw',
			  isa       => 'ArrayRef',
			  default   => sub { [] },
			  handles   => {
					'push_herfd_file_list'  => 'push',
					'pop_herfd_file_list'   => 'pop',
					'clear_herfd_file_list' => 'clear',
				       },
			  documentation => "An array reference containing output files from a RIXS sequence."
			 );

has 'herfd_pixels_used' => (
			    traits    => ['Array'],
			    is        => 'rw',
			    isa       => 'ArrayRef',
			    default   => sub { [] },
			    handles   => {
					  'push_herfd_pixels_used'  => 'push',
					  'pop_herfd_pixels_used'   => 'pop',
					  'clear_herfd_pixels_used' => 'clear',
					 },
			    documentation => "An array reference containing numbers of illuminate pixels from a RIXS sequence."
			   );



has 'steps' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_steps'  => 'push',
			      'pop_steps'   => 'pop',
			      'clear_steps' => 'clear',
			     },
		documentation => "An array reference containing the user-specified steps of the mask creation process."
	       );

has 'gp' => (is => 'rw', isa => 'Graphics::GnuplotIF', default => sub{Graphics::GnuplotIF->new(style => 'lines')});


#enum 'Xray::BLA::Backends' => ['Imager', 'Image::Magick', 'ImageMagick'];
has 'backend'	=> (is => 'rw', isa => 'Str', default => q{Imager},
		    documentation => 'The tiff reading backend, usually Imager, possible Image::Magick.');

sub import {
  my ($class) = @_;
  strict->import;
  warnings->import;
};

sub read_ini {
  my ($self, $configfile) = @_;

  tie my %ini, 'Config::IniFiles', ( -file => $configfile );

  $self -> scanfolder($ini{measure}{scanfolder})      if exists($ini{measure}{scanfolder});
  $self -> tifffolder($ini{measure}{tiffolder})       if exists($ini{measure}{tiffolder});
  $self -> outfolder ($ini{measure}{outfolder})       if exists($ini{measure}{outfolder});
  $self -> element   ($ini{measure}{element})         if exists($ini{measure}{element});
  $self -> line	     ($ini{measure}{line})            if exists($ini{measure}{line});

  $self -> bad_pixel_value   ($ini{pixel}{bad})       if exists $ini{pixel}{bad};
  $self -> weak_pixel_value  ($ini{pixel}{weak})      if exists $ini{pixel}{weak};
  $self -> lonely_pixel_value($ini{pixel}{lonely})    if exists $ini{pixel}{lonely};
  $self -> social_pixel_value($ini{pixel}{social})    if exists $ini{pixel}{social};
  $self -> radius            ($ini{pixel}{radius})    if exists $ini{pixel}{radius};
  $self -> operation         ($ini{pixel}{operation}) if exists $ini{pixel}{operation};
  $self -> scalemask         ($ini{pixel}{scalemask}) if exists $ini{pixel}{scalemask};

  $self -> elastic_energies($self->parse_emission_line($ini{measure}{emission}));

  my $value = (ref($ini{steps}{steps}) eq q{ARRAY}) ? $ini{steps}{steps} : [$ini{steps}{steps}];
  $self->steps($value);

  return $self;
};

sub parse_emission_line {	# return an array reference containing the elastic energies
  my ($self, $string) = @_;
  return [] if not defined $string;
  my @list = split(" ", $string);
  return [$list[0]] if ($#list == 0);  # one energy in list

  my @elastic = ();
  given ($list[1]) {

    when ('to') {		# <start> to <end> by <step>
      my $eee = $list[0];	#    0     1   2    3    4
      push @elastic, $eee;
      while ($eee < $list[2]) {
	$eee += $list[4];
	push @elastic, $eee;
      };
    };

    when (m{\d+}) {		# list of energies
      @elastic = @list
    };

    default {			# list of energies, I guess
      @elastic = @list
    };

  };
  return \@elastic;
};

sub mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{save}    || 0;
  $args{verbose} || 0;
  $args{animate} || 0;
  $args{write}    = 0;
  $args{write}    = 1 if ($args{animate} or $args{save});
  local $|=1;

  $self->clear_bad_pixel_list;
  $self->npixels(0);

  my $ret = $self->check;
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red');
  };

  ## import elastic image and store basic properties
  my @out = ();
  $out[0] = ($args{write}) ? $self->mask_file("0", 'gif') : 0;
  $self->do_step('import_elastic_image', $out[0], $args{verbose}, 0);

  my $i=0;
  foreach my $st (@{$self->steps}) {
    my $set_npixels = ($st eq $self->steps->[-1]) ? 1 : 0;

    my @args = split(" ", $st);

    given ($args[0]) {
      when ('bad')  {
	$self -> bad_pixel_value($args[1]);
	$self -> weak_pixel_value($args[3]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('bad_pixels', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('multiply')  {
	$self->scalemask($args[2]);
	print $self->assert("Multiply image by ".$self->scalemask, 'cyan') if $args{verbose};
	$self->elastic_image->inplace->mult($self->scalemask, 0);
      };

      when ('areal')  {
	$self->operation($args[1]);
	$self->radius($args[3]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('areal', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('lonely')  {
	$self->lonely_pixel_value($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('lonely_pixels', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('social')  {
	$self->social_pixel_value($args[1]);
	push @out, ($args{write}) ? $self->mask_file(++$i, 'gif') : 0;
	$self->do_step('social_pixels', $out[-1], $args{verbose}, $set_npixels);
      };

      when ('entire') {
	print $self->assert("Using entire image", 'cyan') if $args{verbose};
	$self->elastic_image(PDL::Core::ones($self->columns, $self->rows));
      };

      default {
	print assert("I don't know what to do with \"$st\"", 'bold red');
      };
    };
  };

  ## bad pixels may have been turned back on in the social, areal, or entire pass, so turn them off again
  $self->remove_bad_pixels;

  ## construct an animated gif of the mask building process
  if ($args{animate}) {
    my $fname = $self->animate('anim', @out);
    print $self->assert("Wrote $fname", 'yellow'), "\n" if $args{verbose};
  };
  if ($args{save}) {
    my $fname = $self->mask_file("mask", 'gif');
    $self->elastic_image->wim($fname);
    print $self->assert("Saved mask to $fname", 'yellow'), "\n" if $args{verbose};
  };
  unlink $_ foreach @out;

};

sub remove_bad_pixels {
  my ($self) = @_;
  foreach my $pix (@{$self->bad_pixel_list}) {
    my $co = $pix->[0];
    my $ro = $pix->[1];
    $self->elastic_image->($co, $ro) .= 0;
    ## for .=, see assgn in PDL::Ops
    ## for ->() syntax see PDL::NiceSlice
  };
};


sub do_step {
  my ($self, $step, $write, $verbose, $set_npixels) = @_;
  my $ret = $self->$step(write=>$write, unity=>$set_npixels);
  if ($ret->status == 0) {
    die $self->assert($ret->message, 'bold red').$/;
  } else {
    print $ret->message if $verbose;
  };
  $self->npixels($ret->status) if $set_npixels;
  undef $ret;
  return 1;
};

sub check {
  my ($self) = @_;

  my $ret = Xray::BLA::Return->new;

  ## does elastic file exist?
  my $elastic = join("_", $self->stub, 'elastic', $self->energy).'_00001.tif';
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
  my $scanfile = File::Spec->catfile($self->scanfolder, $self->stub.'.001');
  $self->scanfile($scanfile);
  if (not -e $scanfile) {
    $ret->message("Scan file \"$elastic\" does not exist");
    $ret->status(0);
    return $ret;
  };
  if (not -r $scanfile) {
    $ret->message("Scan file \"$elastic\" cannot be read");
    $ret->status(0);
    return $ret;
  };

  # $self->backend('ImageMagick') if $self->backend eq 'Image::Magick';
  # if (not $self->backend) {	# try Imager
  #   my $imager_exists       = eval "require Imager" || 0;
  #   $self->backend('Imager') if $imager_exists;
  # };
  # if (not $self->backend) {	# try Image::Magick
  #   my $image_magick_exists = eval "require Image::Magick" || 0;
  #   $self->backend('ImageMagick') if $image_magick_exists;
  # };
  # if (not $self->backend) {
  #   $ret->message("No BLA backend has been defined");
  #   $ret->status(0);
  #   return $ret;
  # };

  # eval {apply_all_roles($self, 'Xray::BLA::Backend::'.$self->backend)};
  # if ($@) {
  #   $ret->message("BLA backend Xray::BLA::Backend::".$self->backend." could not be loaded");
  #   $ret->status(0);
  #   return $ret;
  # };

  my $img = Xray::BLA::Image->new(parent=>$self);
  $self->elastic_image($img->Read($self->elastic_file));

  if (($self->backend eq 'Imager') and ($self->get_version < 0.87)) {
    $ret->message("This program requires Imager version 0.87 or later.");
    $ret->status(0);
    return $ret;
  };
  if (($self->backend eq 'ImageMagick') and ($self->get_version !~ m{Q32})) {
    $ret->message("The version of Image Magick on your computer does not support 32-bit depth.");
    $ret->status(0);
    return $ret;
  };

  return $ret;
};

sub import_elastic_image {
  my ($self, @args) = @_;
  my %args = @args;
  #$args{write} ||= 0;
  $args{write} = 0;

  my $ret = Xray::BLA::Return->new;

  my ($c, $r) = $self->elastic_image->dims;
  $self->columns($c);
  $self->rows($r);
  my $str = $self->assert("\nProcessing ".$self->elastic_file, 'yellow');
  $str   .= sprintf "\tusing the %s backend\n", $self->backend;
  $str   .= sprintf "\t%d columns, %d rows, %d total pixels\n",
    $self->columns, $self->rows, $self->columns*$self->rows;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub bad_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} ||= 0;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $bpv   = $self->bad_pixel_value;
  my $wpv   = $self->weak_pixel_value;
  my $nrows = $self->rows - 1;

  my ($removed, $toosmall, $on, $off) = (0,0,0,0);
  foreach my $co (0 .. $self->columns-1) {
    foreach my $ro (0 .. $nrows) {
      my $val = $ei->at($co, $ro);
      if ($val > $bpv) {
	$self->push_bad_pixel_list([$co,$ro]);
  	$ei -> ($co, $ro) .= 0;
	## for .=, see assgn in PDL::Ops
	## for ->() syntax see PDL::NiceSlice
  	++$removed;
  	++$off;
      } elsif ($val < $wpv) {
  	$ei -> ($co, $ro) .= 0;
  	++$toosmall;
  	++$off;
      } else {
  	if ($val) {++$on} else {++$off};
      };
    };
  };

  $self->nbad($removed);
  my $str = $self->assert("Bad/weak pass", 'cyan');
  $str   .= "\tRemoved $removed bad pixels and $toosmall weak pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub lonely_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  $args{write} ||= 0;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $lpv   = $self->lonely_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($removed, $on, $off, $co, $ro, $cc, $rr) = (0,0,0);
  foreach my $co (0 .. $ncols) {
    foreach my $ro (0 .. $nrows) {

      ++$off, next if ($ei->at($co, $ro) == 0);

      my $count = 0;
    OUTER: foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc < 0));
	next if (($co == $ncols) and ($cc > 0));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr < 0));
	  next if (($ro == $nrows) and ($rr > 0));

	  ++$count if ($ei->at($co+$cc, $ro+$rr) != 0);
	};
      };
      if ($count < $lpv) {
	$ei -> ($co, $ro) .= 0;
	## for .=, see assgn in PDL::Ops
	## for ->() syntax see PDL::NiceSlice
	++$removed;
	++$off;
      } else {
	$ei -> ($co, $ro) .= 1 if ($args{unity});
	++$on;
      };
    };
  };

  my $str = $self->assert("Lonely pixel pass", 'cyan');
  $str   .= "\tRemoved $removed lonely pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->message($str);
  return $ret;
};

sub social_pixels {
  my ($self, @args) = @_;
  my %args = @args;
  my $ret = Xray::BLA::Return->new;

  ## a bit of optimization -- avoid repititious calls to fetch $self's attributes
  my $ei    = $self->elastic_image;
  my $spv   = $self->social_pixel_value;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my ($added, $on, $off, $count, $co, $ro) = (0,0,0,0,0,0);
  my @addlist = ();
  my ($arg, $val) = (q{}, q{});
  foreach $co (0 .. $ncols) {
    foreach $ro (0 .. $nrows) {

      if ($ei->at($co, $ro) > 0) {
	++$on;
	$ei -> ($co, $ro) .= 1;
	next;
      }

      $count = 0;
    OUTER: foreach my $cc (-1 .. 1) {
	next if (($co == 0) and ($cc == -1));
	next if (($co == $ncols) and ($cc == 1));
	foreach my $rr (-1 .. 1) {
	  next if (($cc == 0) and ($rr == 0));
	  next if (($ro == 0) and ($rr == -1));
	  next if (($ro == $nrows) and ($rr == 1));

	  ++$count if ($ei->at($co+$cc, $ro+$rr) != 0);
	  last OUTER if ($count > $spv);
	};
      };
      if ($count > $spv) {
	push @addlist, [$co, $ro];
	++$added;
	++$on;
      } else {
	++$off;
      };
    };
  };
  foreach my $px (@addlist) {
    $ei -> ($px->[0], $px->[1]) .= 1; # if ($args{unity});
    ## for .=, see assgn in PDL::Ops
    ## for ->() syntax see PDL::NiceSlice
  };
  $self->remove_bad_pixels;

  my $str = $self->assert("Social pixel pass", 'cyan');
  $str   .= "\tAdded $added social pixels\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($on);
  $ret->message($str);
  return $ret;
};


sub areal {
  my ($self, @args) = @_;
  my %args = @args;
  my $ret = Xray::BLA::Return->new;

  $self->remove_bad_pixels;
  my $ei    = $self->elastic_image;
  my $nrows = $self->rows - 1;
  my $ncols = $self->columns - 1;

  my @list = ();

  my ($removed, $on, $off, $co, $ro, $cc, $rr, $cdn, $cup, $rdn, $rup, $value) = (0,0,0,0,0,0,0,0,0,0,0,0);
  my $counter = q{};
  $counter = Term::Sk->new('Areal '.$self->operation.', time elapsed: %8t %15b (column %c of %m)',
			   {freq => 's', base => 0, target=>$ncols}) if $self->screen;

  my $radius = $self->radius;
  foreach my $co (0 .. $ncols) {
    $counter->up if $self->screen;
    $cdn = ($co < $radius)        ? 0      : $co-$radius;
    $cup = ($co > $ncols-$radius) ? $ncols : $co+$radius;
    foreach my $ro (0 .. $nrows) {

      $rdn = ($ro < $radius)        ? 0      : $ro-$radius;
      $rup = ($ro > $nrows-$radius) ? $nrows : $ro+$radius;
      my $slice = $ei->($cdn:$cup, $rdn:$rup);
      $value = ($self->operation eq 'median') ? $slice->flat->oddmedover : int($slice->flat->average);
      ## oddmedover, average: see PDL::Ufunc
      ## flat: see PDL::Core
      ## also see PDL::NiceSlice for matrix slicing syntax

      $value = 1 if (($value > 0) and ($args{unity}));
      push @list, [$co, $ro, $value];
      ($value > 0) ? ++$on : ++$off;
    };
  };
  $counter->close if $self->screen;
  foreach my $point (@list) {
    $ei -> ($point->[0], $point->[1]) .= $point->[2];
    ## for .=, see assgn in PDL::Ops
    ## for ->() syntax see PDL::NiceSlice
  };
  $self->remove_bad_pixels;

  my $str = $self->assert("Areal ".$self->operation." pass", 'cyan');
  my $n = 2*$self->radius+1;
  $str   .= "\tSet each pixel to the ".$self->operation." value of a ${n}x$n square centered at that pixel\n";
  $str   .= sprintf "\t%d illuminated pixels, %d dark pixels, %d total pixels\n",
    $on, $off, $on+$off;
  $self->elastic_image->wim($args{write}, {COLOR=>'bw'}) if $args{write};
  ## wim: see PDL::IO::Pic
  $ret->status($on);
  $ret->message($str);
  return $ret;
};





sub mask_file {
  my ($self, $which, $type) = @_;
  $type ||= 'gif';
  $type = 'tif' if ($^O =~ /MSWin32/);
  my $fname;
  if ($which eq 'map') {
    my $range = join("-", $self->elastic_energies->[0], $self->elastic_energies->[-1]);
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $range, "map", "anim").'.');
  } elsif ($which eq 'anim') {
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, "mask", "anim").'.');
  } else {
    my $id = ($which eq 'mask') ? q{} :"_$which";
    $fname = File::Spec->catfile($self->outfolder, join("_", $self->stub, $self->energy, "mask$id").'.');
  };
  $fname .= $type;
  return $fname;
};


# # HERFD scan on Au3MarineCyanos1
# # ----------------------------------
# # energy time ring_current i0 it ifl ir roi1 roi2 roi3 roi4 tif
#     11850.000   20  95.3544291727  1400844   830935   653600   956465      38      18      15      46      1

sub read_mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  my $ret = Xray::BLA::Return->new;
  my $fname = $self->mask_file("mask", 'gif');
  if (not -e $fname) {
    $ret->status(0);
    $ret->message("mask file $fname does not exist");
    return $ret;
  };
  my $image = rim($fname);
  $self -> elastic_image($image);
  print $self->assert("Read mask from ".$fname, 'yellow') if $args{verbose};
  return $ret;
};

sub scan {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{xdiini}  ||= q{};
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  my (@data, @point);

  print $self->assert("Reading scan from ".$self->scanfile, 'yellow') if $args{verbose};
  open(my $SCAN, "<", $self->scanfile);
  while (<$SCAN>) {
    next if m{\A\#};
    next if m{\A\s*\z};
    chomp;
    @point = ();
    my @list = split(" ", $_);

    my $loop = $self->apply_mask($list[11], verbose=>$args{verbose});
    push @point, $list[0];
    push @point, sprintf("%.10f", $loop->status/$list[3]);
    push @point, @list[3..6];
    push @point, $loop->status;
    push @point, @list[1..2];
    push @data, [@point];
  };
  close $SCAN;

  my $outfile;
  if (($XDI_exists) and (-e $args{xdiini})) {
    $outfile = $self->xdi_out($args{xdiini}, \@data);
  } else {
    $outfile = $self->dat_out(\@data);
  };

  $ret->message($outfile);
  print $self->assert("Wrote $outfile", 'bold green') if $args{verbose};
  return $ret;
};


sub xdi_out {
  my ($self, $xdiini, $rdata) = @_;
  my $fname = join("_", $self->stub, $self->energy) . '.xdi';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  my $xdi = Xray::XDI->new();
  $xdi   -> ini($xdiini);
  $xdi   -> push_extension(sprintf("BLA.illuminated_pixels: %d", $self->npixels));
  $xdi   -> push_extension(sprintf("BLA.total_pixels: %d", $self->columns*$self->rows));
  $xdi   -> push_extension("BLA.pixel_ratio: \%pixel_ratio\%") if ($self->task eq 'rixs');
  $xdi   -> push_comment("HERFD scan on " . $self->stub);
  $xdi   -> push_comment("Mask building steps:");
  foreach my $st (@{$self->steps}) {
    $xdi -> push_comment("  $st");
  };
  $xdi   -> data($rdata);
  $xdi   -> export($outfile);
  return $outfile;
};

sub dat_out {
  my ($self, $rdata) = @_;
  my $fname = join("_", $self->stub, $self->energy) . '.dat';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  open(my $O, '>', $outfile);
  print   $O "# HERFD scan on " . $self->stub . $/;
  printf  $O "# %d illuminated pixels (of %d) in the mask\n", $self->npixels, $self->columns*$self->rows;
  printf  $O "# Mask building steps:\n";
  foreach my $st (@{$self->steps}) {
    printf  $O "#    $st\n";
  };
  print   $O "# -------------------------\n";
  print   $O "#   energy      mu           i0           it          ifl         ir          herfd   time    ring_current\n";
  foreach my $p (@$rdata) {
    printf $O "  %.3f  %.7f  %10d  %10d  %10d  %10d  %10d  %4d  %8.3f\n", @$p;
  };
  close   $O;
  return $outfile;
};

sub apply_mask {
  my ($self, $tif, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{silence} ||= 0;
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  my $fname = sprintf("%s_%5.5d.tif", $self->stub, $tif);
  my $image = File::Spec->catfile($self->tiffolder, $fname);
  if (not -e $image) {
    warn "\tskipping $image, file not found\n" if not $args{silence};
    $ret->message("skipping $image, file not found\n");
    $ret->status(0);
  } elsif (not -r $image) {
    warn "\tskipping $image, file cannot be read\n" if not $args{silence};
    $ret->message("skipping $image, file cannot be read\n");
    $ret->status(0);
  } else {
    printf("  %3d, %s", $tif, $image) if ($args{verbose} and (not $tif % 10));

    ## * is pixel by pixel multiplication of mask and datapoint: see mult in PDL::Ops
    ## sumover: see PDL::Ufunc
    ## flat, sclr: see PDL::Core
    my $masked = $self->elastic_image * Xray::BLA::Image->new(parent=>$self)->Read($image);
    my $sum = int($masked->flat->sumover->sclr);
    printf("  %7d\n", $sum) if ($args{verbose} and (not $tif % 10));
    $ret->status($sum);
  };
  return $ret;
};

sub prep_rixs_for_normalization {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  my $ret = Xray::BLA::Return->new;

  my $max = max(@{$self->herfd_pixels_used});
  my @used = map {sprintf("%.3f", $max/$_)} @{$self->herfd_pixels_used};
  foreach my $i (0 .. $#used) {
    local $/;
    open(my $IN, '<', $self->herfd_file_list->[$i]);
    my $text = <$IN>;
    close $IN;
    $text =~ s{\%pixel_ratio\%}{$used[$i]};
    open(my $OUT, '>', $self->herfd_file_list->[$i]);
    print $OUT $text;
    close $OUT;
  };
  print $self->assert("Prepared HERFD files for pixel count normalization", 'yellow') if $args{verbose};
  return $ret;
};

sub rixs_map {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  my $ret = Xray::BLA::Return->new;

  my $outfile = File::Spec->catfile($self->outfolder, $self->stub.'_rixs.map');
  open(my $M, '>', $outfile);

  my $count = 0;
  my (@x, @y, @all);
  foreach my $file (@{$self->herfd_file_list}) {
    @x = () if $count == 0;	# gather energy axis from first file
    @y = ();
    open(my $f, '<', $file);
    foreach my $line (<$f>) {
      next if $line =~ m{\A\s*\z};
      next if $line =~ m{\A\s*\#};
      my @list = split(" ", $line);
      push @x, $list[0] if $count == 0;
      push @y, $list[1];
    };
    push @all, [@y];
    close $f;
    ++$count;
  };
  foreach my $i (0 .. $#x) {
    foreach my $ie (0 .. $#{$self->elastic_energies}) {
      print $M $x[$i], "   ", $self->elastic_energies->[$ie], "   ", $all[$ie]->[$i], $/;
    };
    print $M $/;
  };
  close $M;
  print $self->assert("Wrote rixs map to $outfile", 'bold green') if $args{verbose};

  return $ret;
};

sub energy_map {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{animate} ||= 0;
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  ## determine the average step between elastic measurements
  my @energies = sort {$a <=> $b} @{$self->elastic_energies};
  my $step = round( sum(map {$energies[$_+1] - $energies[$_]} (0 .. $#energies-1)) / $#energies );

  ## import the gifs of each elastic map
  my @images = map {rim($_)} @{$self->elastic_file_list};
  $self -> elastic_image_list(\@images);

  my $counter = Term::Sk->new('Making map, time elapsed: %8t %15b (row %c of %m)',
			      {freq => 's', base => 0, target=>$self->rows});
  my $outfile = File::Spec->catfile($self->outfolder, $self->stub.'.map');
  open(my $M, '>', $outfile);
  printf $M "# Energy calibration map for %s\n", $self->stub;
  printf $M "# Elastic energy range [%s : %s]\n", $energies[0], $energies[-1];
  print  $M "# ----------------------------------\n";
  print  $M "# row  column  interpolated_energy\n\n";
  my $ncols = $self->columns - 1;

  foreach my $r (0 .. $self->rows-1) {
    $counter->up if $self->screen;

    my @represented = map {[0]} (0 .. $self->columns-1);
    my @linemap = map {0} (0 .. $self->columns-1);
    my (@x, @y);
    my @all = ();

    ## gather current row from each mask
    foreach my $ie (0 .. $#{$self->elastic_energies}) {
      ## extract the $r-th row from each image and fl;atten it to a 1D PDL
      my $y = $self->elastic_image_list->[$ie] -> (0:$ncols,$r) -> flat;
      push @all, $y;
    };


    ## accumulate energies at which each pixel is illuminated
    my $stripe = 0;
    foreach my $list (@all) {
      foreach my $p (0 .. $ncols) {
	if ($list->at($p) > 0) {
	  push @{$represented[$p]}, $self->elastic_energies->[$stripe];
	};
      };
      ++$stripe;
    };

    ## make each pixel the average of energies at which the pixel is illuminated
    foreach my $i (0 .. $#represented) {
      my $n = sprintf("%.1f", $#{$represented[$i]});
      my $val = '(' . join('+', @{$represented[$i]}) . ')/' . $n;
      $linemap[$i] = eval "$val" || 0;
    };

    ## linearly interpolate from the left to fill in any gaps from the measured masks
    $linemap[0] ||= $self->elastic_energies->[0]-$step;
    my $flag = 0;
    my $first = 0;
    foreach my $k (1 .. $#linemap) {
      $flag = 1 if ($linemap[$k] == 0);
      $first = $k if not $flag;
      if ($flag and ($linemap[$k] > 0)) {
	my $emin = $linemap[$first];
	my $ediff = $linemap[$k] - $emin;
	foreach my $j ($first .. $k-1) {
	  $linemap[$j] = $emin + (($j-$first)/($k-$first)) * $ediff;
	};
	$flag = 0;
      };
    };
    if ($flag) {
      my $emin = $linemap[$first-1];
      my $ediff = $step; # FIXME: this should be the actual step between adjacent elastic measurements
      foreach my $j ($first .. $#linemap) {
	$linemap[$j] = $emin + (($j-$first)/($#linemap-$first)) * $ediff;
      };
    };

    ## do three-point smoothing to smooth over abrupt steps in energy
    my @zz = $self->smooth(4, \@linemap);

    ## write this row
    foreach my $i (0..$#zz) {
      print $M "  $r  $i  $zz[$i]\n";
    };
    print $M $/;
  };
  $counter->close if $self->screen;
  close $M;
  print $self->assert("Wrote calibration map to $outfile", 'bold green') if $args{verbose};

  ## write a usable gnuplot script for plotting the data
  my $gpfile = File::Spec->catfile($self->outfolder, $self->stub.'.map.gp');
  my $gp = $self->gnuplot_map;
  my $tmpl = Text::Template->new(TYPE=>'string', SOURCE=>$gp)
    or die "Couldn't construct template: $Text::Template::ERROR";
  open(my $G, '>', $gpfile);
  (my $stub = $self->stub) =~ s{_}{\\\\_}g;
  my $peak = Xray::Absorption->get_energy($self->element, $self->line)
    || ( ($self->elastic_energies->[$#{$self->elastic_energies}]+$self->elastic_energies->[0]) /2 );
  print $G my $string = $tmpl->fill_in(HASH => {emin  => $self->elastic_energies->[0],
						emax  => $self->elastic_energies->[$#{$self->elastic_energies}],
						file  => $outfile,
						stub  => $stub,
						nrows => $self->rows,
						ncols => $self->columns,
						step  => $step,
						peak  => $peak,
					       });
  close $G;
  print $self->assert("Wrote gnuplot script to $gpfile", 'bold green') if $args{verbose};
  $ret->message($gpfile);

  if ($args{animate}) {
    my $animfile = $self->animate('map', @{$self->elastic_file_list});
    print $self->assert("Wrote gif animation of energy map to $animfile", 'bold green') if $args{verbose};
  };

  return $ret;
};


# ## snarf (quietly!) the list of energies from the list used for the
# ## next_energy function in Xray::Absoprtion::Elam
# my $hash;
# do {
#   no warnings;
#   $hash = $$Xray::Absorption::Elam::r_elam{line_list};
# };
# my @line_list = ();
# foreach my $key (keys %$hash) {
#   next unless exists $$hash{$key}->[2];
#   next unless ($$hash{$key}->[2] > 100);
#   push @line_list, $$hash{$key};
# };
# ## and sort by increasing energy
# @line_list = sort {$a->[2] <=> $b->[2]} @line_list;


## swiped from ifeffit-1.2.11d/src/lib/decod.f, lines 453-461
sub smooth {
  my ($self, $repeats, $rarr) = @_;
  my @array = @$rarr;
  return @array if ($repeats == 0);
  my @smoothed = ();
  foreach my $x (1 .. $repeats) {
    $smoothed[0] = 3*$array[0]/4.0 + $array[1]/4.0;
    foreach my $i (1 .. $#array-1) {
      $smoothed[$i] = ($array[$i] + ($array[$i+1] + $array[$i-1])/2.0)/2.0;
    };
    $smoothed[$#array] = 3*$array[$#array]/4.0 + $array[$#array-1]/4.0;
    @array = @smoothed;
  };
  return @smoothed;
};


sub gnuplot_map {
  my ($self) = @_;
  my $text = q<set term wxt font ",9"  enhanced

set auto
set key default
set pm3d map

set title "\{/=14 {$stub} energy map\}" offset 0,-5
set ylabel "\{/=11 columns\}" offset 0,2.5

set view 0,90,1,1
set origin -0.17,-0.2
set size 1.4,1.4
unset grid

unset ztics
unset zlabel
set xrange [{$nrows}:0]
set yrange [0:{$ncols}]
set cbtics {$emin-$step}, {2*$step}, {$emax+$step}
set cbrange [{$emin-$step}:{$emax+$step}]

set colorbox vertical size 0.025,0.65 user origin 0.03,0.15

set palette model RGB defined ( {$emin-$step-$peak} 'red', 0 'white', {$emax+$step-$peak} 'blue' )

splot '{$file}' title ''
>;
  return $text;
};

## heat scale
#set palette model RGB defined ( -1 'black', 0 'red', 1 'yellow', 2 'white' )

## undersaturated rainbow
#set palette model RGB defined (0 '#990000', 1 'red', 2 'orange', 3 'yellow', 4 'green', 5 '#009900', 6 '#006633', 7 '#0066DD', 8 '#000099')

## gray scale
#set palette model RGB defined ( 0 'black', 1 'white' )

sub compute_xes {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{inident} ||= 0;
  my $ret = Xray::BLA::Return->new;

  $self->get_incident($args{incident});
  print $self->assert("Making XES at incident energy ".$self->incident, 'yellow') if $args{verbose};

  my @values  = ();
  my @npixels = ();
  my $counter = Term::Sk->new('Computing XES, time elapsed: %8t %15b (emission energy %c of %m)',
			      {freq => 's', base => 0, target=>$#{$self->elastic_energies}});
  foreach my $e (@{$self->elastic_energies}) {
    $counter->up if $self->screen;
    $self -> energy($e);
    my $ret = $self -> read_mask(verbose=>0);
    print(0) && exit(1) if not $ret->status;
    my $value = $self->apply_mask($self->nincident, verbose=>0, silence=>1)->status;
    my $np = int($self->elastic_image->flat->sumover->sclr);
    push @values, $value;
    push @npixels, $np;
    #print "$e  $value  $np\n";
  };
  $counter->close if $self->screen;
  my $max = max(@npixels);
  @npixels = map {$max / $_} @npixels;

  my @xes = ();
  foreach my $i (0 .. $#npixels) {
    push @xes, [$self->elastic_energies->[$i], $npixels[$i]*$values[$i]];
  };
  my $outfile;
  if (($XDI_exists) and (-e $args{xdiini})) {
    $outfile = $self->xdi_xes($args{xdiini}, \@xes);
  } else {
    $outfile = $self->dat_xes(\@xes);
  };
  $ret->message($outfile);
  print $self->assert("Wrote $outfile", 'bold green') if $args{verbose};
  return $ret;
};

sub get_incident {
  my ($self, $in) = @_;
  my $scanfile = File::Spec->catfile($self->scanfolder, $self->stub.'.001');
  $self->scanfile($scanfile);
  open(my $S, '<', $self->scanfile);
  my @energy = ();
  while (<$S>) {
    next if ($_ =~ m{\A\#});
    my @list = split(" ", $_);
    push @energy, $list[0];
  };
  if ($in == 0) {
    my $n = int($#energy/2);
    $self->incident($energy[$n]);
    $self->nincident($n);
  } elsif (($in =~ m{\A\d+\z}) and ($in < 1000)) {
    $self->incident($energy[$in]);
    $self->nincident($in);
  } elsif (not looks_like_number($in)) {
    die "BLA error: incident energy (-i switch) is not a number\n";
  } else {
    my $n = 0;
    while (($in > $energy[$n]) and ($n < $#energy)) {
      ++$n;
    };
    $self->incident($energy[$n]);
    $self->nincident($n);
    #print $n, "  ", $energy[$n], $/;
  };
};

sub xdi_xes {
  my ($self, $xdiini, $rdata) = @_;
  my $fname = join("_", $self->stub, 'xes', $self->incident) . '.xdi';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  my $xdi = Xray::XDI->new();
  $xdi   -> ini($xdiini);
  $xdi   -> push_comment("XES from " . $self->stub . " at " . $self->incident . ' eV');
  $xdi   -> data($rdata);
  $xdi   -> export($outfile);
  return $outfile;
};
sub dat_xes {
  my ($self, $rdata) = @_;
  my $fname = join("_", $self->stub, 'xes', $self->incident) . '.dat';
  my $outfile  = File::Spec->catfile($self->outfolder,  $fname);

  open(my $O, '>', $outfile);
  print   $O "# XES from " . $self->stub . " at " . $self->incident . ' eV' . $/;
  print   $O "# -------------------------\n";
  print   $O "#   energy      xes\n";
  foreach my $p (@$rdata) {
    printf $O "  %.3f  %.7f\n", @$p;
  };
  close   $O;
  return $outfile;
};


sub assert {
  my ($self, $message, $color) = @_;
  my $string = ($self->colored) ? Term::ANSIColor::colored($message, $color) : $message;
  return $string.$/;
};

sub do_plot {
  my ($self, $fname, @args) = @_;
  my %args = @args;
  $args{type}  ||= q{data};
  $args{title} ||= q{};
  $args{pause} ||= q{-1};
  my $str = ($args{type} eq 'data') ? 'plot \'' . $fname . "' title '" . $args{title} . "'\n"
          :                           'load \'' . $fname . "'\n";
  #print $str;
  $self->gp->gnuplot_cmd($str);
  $self->pause($args{pause});
}


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Xray::BLA - Convert bent-Laue analyzer + Pilatus 100K data to a XANES spectrum

=head1 VERSION

0.6

=head1 SYNOPSIS

   use Xray::BLA; # automatically turns on strict and warnings

   my $spectrum = Xray::BLA->new;

   $spectrum->read_ini("config.ini"); # set attributes from ini file
   $spectrum->stub('myscan');
   $spectrum->energy(9713);

   $spectrum->mask(verbose=>1, write=>0, animate=>0);
   $spectrum->scan(verbose=>1);

Xray::BLA imports C<warnings> and C<strict> by default.

=head1 DESCRIPTION

This module is an engine for converting a series of tiff images
collected using a bent Laue analyzer and a Pilatus 100K area detector
into a high energy resolution XANES spectrum.  A HERFD measurement
consists of a related set of files from the measurement:

=over

=item 1.

A column data file containing the energy, signals from other scalars,
and a few other columns

=item 2.

A tiff image of an exposure at each energy point.  This image must be
interpreted to be the HERFD signal at that energy point.

=item 3.

A set of one or more exposures taken at incident energies around the
peak of the fluorescence line (e.g. Lalpha1 for an L3 edge, etc).
These exposures are used to make masks for interpreting the sequence
of images at each energy point.

=back

Attributes for specifying the paths to the locations of the column
data files (C<scanfolder>) and the tiff files (C<tiffolder>,
C<tifffolder> with 3 C<f>'s is an alias)) are typically set from an
ini-style configuration file.

Assumptions are made about the names of the files in those
locations. Each files is built upon a stub, indicated by the C<stub>
attribute.  If C<stub> is "Aufoil", then the column data in
C<scanfolder> file is named F<Aufoil.001>.  The tiff images at each
energy point are called F<Aufoil_NNNNN.tif> where C<NNNNN> is the
index of the energy point.  One of the columns in the scan file
contains this index so it is unambiguous which tiff image corresponds
to which energy point.  Finally, the elastic exposures are called
F<Aufoil_elastic_EEEE_00001.tif> where C<EEEE> is the incident
energy. For instance, an exposure at the peak of the gold Lalpha1 line
would be called F<Aufoil_elastic_9713_00001.tif>.

If you use a different naming convention, this software in its current
form B<will break>!  See L</"BUGS AND LIMITATIONS">.

This software uses an image handling back to interact with these two
sets of tiff images.  Since the Pilatus writes rather unusual tiff
files with signed 32 bit integer samples, not every image handling
package can deal gracefully with them.  I have found two choices in
the perl universe that work well, L<Imager> and C<Image::Magick>,
although using L<Image::Magick> requires recompilation to be able to
use 32 bit sample depth.  Happily, L<Imager> works out of the box, so
I am using it.

The signed 32 bit tiffs are imported using L<Imager> and immediately
stuffed into a L<PDL> object.  All subsequent work is done using PDL.

=head1 ATTRIBUTES

=over 4

=item C<stub>

The basename of the scan and image files.  The scan file is called
C<E<lt>stubE<gt>.001>, the image files are called
C<E<lt>stubE<gt>_NNNNN.tif>, and the processed column data files are
called C<E<lt>stubE<gt>_E<lt>energyE<gt>.001>.

=item C<element>

The element of the absorber.  This is currently only used when making
the energy v. pixel map.  This can be a two-letter element symbol, a Z
number, or an element name in English (e.g. Au, 79, or gold).

=item C<line>

The measured emission line.  This is currently only used when making
the energy v. pixel map.  This can be a Siegbahn (e.g. La1 or Lalpha1)
or IUPAC symbol (e.g. L3-M5).

=item C<scanfile>

The fully resolved path to the scan file, as determined from C<stub>
and C<scanfolder>.

=item C<scanfolder>

The folder containing the scan file.  The scan file name is
constructed from the value of C<stub>.

=item C<tiffolder>

The folder containing the image files.  The image file names are
constructed from the value of C<stub>.  C<tifffolder> (with 3 C<f>'s)
is an alias.

=item C<outfolder>

The folder to which the processed file is written.  The processed file
name is constructed from the value of C<stub>.

=item C<energy>

This normally takes the tabulated value of the measured fluorescence
line.  For example, for the the gold L3 edge experiment, the L alpha 1
line is likely used.  It's tabulated value is 9715 eV.

The image containing the data measured from the elastic scattering
with the incident energy at this energy will have a file name something
like F<E<lt>stubE<gt>_elsatic_E<lt>energyE<gt>_00001.tif>.

This value can be changed to some other measured elastic energy in
order to scan the off-axis portion of the spectrum.

C<peak_energy> is an alias for C<energy>.

=item C<incident>

The incident energy for an XES slice through the RIXS or for
evaluation of single HERFD data point.  If not specified, it defaults
to the midpoint of the energy scan.

=item C<nincident>

The index of the incident energy for an XES slice through the RIXS or
for evaluation of single HERFD data point.  If not specified, it
defaults to the midpoint of the energy scan.

=item C<steps>

This contains a reference to an array of steps to be taken for mask
creation.  For example, if the configuration file contains the
following:

   ## areal algorithm
   [steps]
   steps = <<END
   bad 400 weak 0
   areal median radius 2
   END

then the lines beginning with "bad" and "areal" will be the entries in
the array, indicating that first bad and weak pixels will be removed
using the specifies values for C<bad_pixel_value> and
C<weak_pixel_value>, then an areal median of radius 2 will be computed.

=item C<operation>  [median]

Setting this to "mean" changes the areal median algorithm to an areal
mean algorithm.

=item C<bad_pixel_value>  [400]

In the first pass over the elastic image, spuriously large pixel
values -- presumably indicating the locations of bad pixels -- are
removed from the image by setting them to 0.  This is the cutoff value
above which a pixel is assumed to be a bad one.

=item C<weak_pixel_value> [3]

In the first pass over the elastic image, small valued pixels are
removed from the image.  These pixels are presumed to have been
illuminated by a small number of stray photons not associated with the
imagining of photons at the peak energy.  Pixels with fewer than this
n umber of counts are set to 0.

=item C<lonely_pixel_value> [3]

In the second pass over the elastic image, illuminated pixels with
fewer than this number of illuminated neighboring pixels are removed
from the image.  This serves the purpose of removing most stray
pixels not associated with the main image of the peak energy.

This attribute is ignored by the areal median/mean algorithm.

=item C<social_pixel_value> [2]

In the third pass over the elastic image, dark pixels which are
surrounded by larger than this number of illuminated pixels are
presumed to be a part of the image of the peak energy.  They are given
a value of 5 counts.  This serves the propose of making the elastic
image a solid mask with few gaps in the image of the main peak.

This attribute is ignored by the areal median/mean algorithm.

=item C<radius> [2]

This determines the size of the square used in the areal median/mean
algorithm.  A value of 1 means to use a 3x3 square, i.e. 1 pixel in
each direction.  A value of 2 means to use a 5x5 square.  Thanks to
PDL, the hit for using a larger radius is quite small.

=item C<elastic_file>

This contains the name of the elastic image file.  It is constructed
from the values of C<stub>, C<energy>, and C<tiffolder>.

=item C<elastic_image>

This contains the backend object corresponding to the elastic image.

=item C<npixels>

The number of illuminated pixels in the mask.  That is, the number of
pixels contributing to the HERFD signal.

=item C<columns>

When the elastic file is read, this is set with the number of columns
in the image.  All images in the measurement are presumed to have the
same number of columns.  C<width> is an alias for C<columns>.

=item C<rows>

When the elastic file is read, this is set with the number of rows in
the image.  All images in the measurement are presumed to have the
same number of rows.  C<height> is an alias for C<rows>.

=item C<colored>

This flag should be true to write colored text to the screen when
methods are called with the verbose flag on.

=item C<screen>

This flag should be true when run from the command line so that
progress messages are written to the screen.

=back

=head1 METHODS

All methods return an object of type L<Xray::BLA::Return>.  This
object has two attributes: C<status> and C<message>.  A successful
return will have a positive definite C<status>.  Any reporting (for
example exception reporting) is done via the C<message> attribute.

Some methods, for example C<apply_mask>, use the return C<status> as
the sum of HERFD counts from the illuminated pixels.

=head2 API

=over 4

=item C<read_ini>

Import an ini-style configuration file to set attributes of the
Xray::BLA object.

  $spectrum -> read_ini("myconfig.ini");

=item C<mask>

Create a mask from the elastic image measured at the energy given by
C<energy>.

  $spectrum->mask(verbose=>0, save=>0, animate=>0);

When true, the C<verbose> argument causes messages to be printed to
standard output with information about each stage of mask creation.

When true, the C<save> argument causes a tif file to be saved at
each stage of processing the mask.

When true, the C<animate> argument causes a properly scaled animation
to be written showing the stages of mask creation.

These output image files are gif.

This method is a wrapper around the contents of the C<step> attribute.
Each entry in C<step> will be parsed and executed in sequence.

=item C<scan>

Rewrite the scan file with a column containing the HERFD signal as
computed by applying the mask to the image file from each data point.

  $spectrum->scan(verbose=>0, xdiini=>$inifile);

When true, the C<verbose> argument causes messages to be printed to
standard output about every data point being processed.

The C<xdiini> argument takes the file name of an ini-style
configuration file for XDI metadata.  If no ini file is supplied, then
no metadata and no column labels will be written to the output file.

An L<Xray::BLA::Return> object is returned.  Its C<message> attribute
contains the fully resolved file name for the output HERFD data file.

=item C<energy_map>

Read the masks from each emission energy and interpolate them to make
a map of pixel vs. energy.  This requires that each mask has already
been generated from the measured elastic image.

  $spectrum -> energy_map(verbose => 1, animate=>0);

When true, the C<verbose> argument causes messages to be printed to
standard output about file written.

When true, the C<animate> argument causes an animated gif file to be
written containing a movie of the processed elastic masks.

The returned L<Xray::BLA::Return> object conveys no information at
this time.

=item C<compute_xes>

Take an XES slice through the RIXS map.  Weight the signal at each
emission energy by the number of pixels illuminated in that mask.

  $spectrum->scan(verbose=>0, xdiini=>$inifile, incident=>$incident);

The C<incident> argument specifies the incident energy of the slice.
If not given, use the midpoint (by index) of the energy array.  If an
small integer is given, use that incident energy point.  If an energy
value is given, use that energy or the nearest larger energy.

When true, the C<verbose> argument causes messages to be printed to
standard output about file written.

The returned L<Xray::BLA::Return> object conveys no information at
this time.

=item C<get_incident>

Given an integer (representing a data point index) or an energy value,
set the C<incident> and C<nincident> attributes with the matching
energy and index values of that point.

    $spectrum->get_incident($point);

If C<$point> is omitted, the C<incident> and C<nincident> attributes
are set with the values of the midpoint (by index) of the data range.

=back

=head2 Internal methods

All of these methods return a L<Xray::BLA::Return> object, which has
two attributes, and integer C<status> to indicate the return status (1
is normal in all cases here) and an string C<message> containing a
short description of the exception (an empty string indicates no
exception).

=over 4

=item C<check>

Confirm that the scan file and elastic image taken from the values of
C<stub> and C<energy> exist and can be read.  Import an imaging
backend and perform checks to make sure that it can support the 32 bit
tiff images.

This is the first thing done by the C<mask> method and must be the
initial chore of any script using this library.

  $spectrum -> check;

=item C<import_elastic_image>

Import the file containing the elastic image and perform the first
pass in which bad pixels and weak pixels are removed from the image.

  $spectrum -> import_elastic_image;

The intermediate image can be saved:

  $spectrum -> import_elastic_image(write => "firstpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=item C<lonely_pixels>

Make the second pass over the elastic image.  Remove illuminated
pixels which are not surrounded by enough other illuminated pixels.

  $spectrum -> lonely_pixels;

The intermediate image can be saved:

  $spectrum -> lonely_pixels(write => "secondpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=item C<social_pixels>

Make the third pass over the elastic image.  Include dark pixels which
are surrounded by enough illuminated pixels.

  $spectrum -> lonely_pixels;

The final mask image can be saved:

  $spectrum -> lonely_pixels(write => "finalpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=item C<areal>

At each point in the mask, assign its value to the median or mean
value of a square centered on that point.  The size of the square is
determined by the value of the C<radius> attribute.

  $spectrum -> areal;

The final mask image can be saved:

  $spectrum -> areal(write => "arealpass.tif");

The C<message> attribute of the return object contains information
regarding mask creation to be displayed if the C<verbose> argument to
C<mask> is true.

=item C<apply_mask>

Apply the mask to the image for a given data point to obtain the HERFD
signal for that data point.

  $spectrum -> apply_mask($tif_number, verbose=>1)

The C<status> of the return object contains the photon count from the
image for this data point.

=back

=head1 MASK SPECIFICATION SYNTAX

The steps to mask creation are specified using a simple imperative
language.  Here's an example of specifying the steps via the
configuration file:

    [steps]
    steps = <<END
    bad 400 weak 0
    multiply by 5
    areal mean radius 2
    bad 400 weak 6
    lonely 3
    social 2
    END

Each specification of a step is contained on a single line.
White space is unimportant, but spelling matters.  The parser has
little intelligence.

The possible steps are:

=over 4

=item C<bad # weak #>

This specification says to remove bad and weak pixels from the image.
The first number is the value used for C<bad_pixel_value>.  The second
number is the value used for C<weak_pixel_value>.

=item C<multiply by #>

This specification says to multiply the image by a constant.  That is,
each pixel will be multiplied by the given constant.

=item C<areal [median|mean] radius #>

Apply the areal median or mean algorithm.  The number specifies the
"radius" over which to apply the median or mean.  A value of 1 says to
construct a 3x3 square, i.e. 1 pixel both ways in both dimensions, a
value of 2 says to construct a 5x5 square, and so on.  Using this
algorithm, the pixel is set to either the median or the mean of the
pixels in the square.

=item C<lonely #>

Turn off a pixel that is not surrounded by enough illuminated pixels.
The purpose of this is to darken isolated pixels.  The number is used
as the value of C<lonely_pixel_value>.  If a pixel is illuminated and
is surrounded by fewer than that number of pixels, it will be turned
off.

=item C<social #>

Turn off a pixel that is surrounded by enough illuminated pixels.  The
purpose of this is to illuminate dark pixels in an illuminated region.
The number is used as the value of C<social_pixel_value>.  If a pixel
is not illuminated and is surrounded by more than that number of pixels,
it will be turned on.

=item C<entire image>

Set all pixels in the image to 1.  That is, use all the pixels in a
image to generate the XANES value.  This is mostly used for testing
purposes and its incompatible with any of the other steps except the
bad pixel pass.  To examine the XANES form the entire image, use this

    [steps]
    steps = <<END
    bad 400 weak 0
    entire image
    END

=back

The steps can be specified in any order and repeated as necessary.

The C<steps> attribute is set is a configuration file containing the
C<[steps]> group is read.  The C<steps> attribute can be manipulated
by hand:

   $spectrum->steps(\@list_of_steps);      # set the steps to an array

   $spectrum->push_steps("multiply by 7"); # add to the end of the list of steps

   $spectrum->pop_steps;                   # remove the last item from the list

   $spectrum->steps([]); # or
   $spectrum->clear_steps;                 # remove all steps from the list


=head1 ERROR HANDLING

If the scan file or the elastic image cannot be found or cannot be
read, a program will die with a message to STDERR to that effect.

If an image file corresponding to a data point cannot be found or
cannot be read, a value of 0 will be written to the output file for
that data point and a warning will be printed to STDOUT.

Any warning or error message involving a file will contain the
complete file name so that the file naming or configuration mistake
can be tracked down.

Missing information expected to be read from the configuration file
will issue an error citing the configuration file.

Errors interpreting the contents of an image file are probably not
handled well.

The output column data file is B<not> written on the fly, so a run
that dies or is halted early will probably result in no output being
written.  The save and animation images are written at the time the
message is written to STDOUT when the C<verbose> switch is on.

=head1 XDI OUTPUT

When a configuration file containing XDI metadata is used, the output
files will be written in XDI format.  This is particularly handy for
the RIXS function.  If XDI metadata is provided, then the
C<BLA.pixel_ratio> datum will be written to the output file.  This
number is computed from the number of pixels illuminated in the mask
at each emission energy.  The pixel ratio for an emission energy is
the number of pixels from the emission energy with the largest number
of illuminated pixels divided by the number of illuminated pixels at
that energy.

The pixel ratio can be used to normalize the mu(E) data from each
emission energy.  The concept is that the normalized mu(E) data are an
approximation of what they would be if each emission energy was
equally represented on the face of the detector.

The version of Athena based on Demeter will be able to use these
values as importance or plot multiplier values if the L<Xray::XDI>
module is available.

=head1 CONFIGURATION AND ENVIRONMENT

Using the script in the F<bin/> directory, file locations, elastic
energies, and mask parameters are specified in an ini-style
configuration file.  An example is found in F<share/config.ini>.

If using L<Xray::XDI>, metadata can be supplied by an ini-style file.
And example is found in F<share/bla.xdi.ini>.

=head1 DEPENDENCIES

This requires perl 5.10 or later.

=head2 CPAN

=over 4

=item *

L<PDL>

=item *

L<Moose>

=item *

L<MooseX::AttributeHelpers>

=item *

L<MooseX::Aliases>

=item *

L<Math::Round>

=item *

L<Config::IniFiles>

=item *

L<Term::Sk>

=item *

L<Text::Template>

=item *

L<Imager>

=item *

L<Xray::XDI>  (optional)

=back

=head2 Image Magick

As delivered to an Ubuntu system, Image Magick cannot handle the TIFF
files as written by the Pilatus 100K imagine detector.  In order to be
able to use Image Magick, it must be recompiled with a larger bit
depth.  This is done by downloading and unpacking the tarball, then
doing

      ./configure --with-quantum-depth=32

I also rebuilt the perl wrapper which comes with the Image Magick
source code.  This also was a bit tricky.  My Ubuntu system has perl
5.10.1 and therefore has a F<libperl.5.10.1.so>.  It did not, however,
have a F<libperl.so> symlinked to it.  To get the perl wrapper to
build, I had to do

      sudo ln -s /usr/lib/libperl.so.5.10.1 /usr/lib/libperl.so

Adjust the version number on the perl library as needed.

I have not been able to rebuild Image Magick with Windows and
MinGW. Happily L<Imager> works out of the box with MinGW and
Strawberry Perl.  Currently, the Image Magick backend is disabled.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

More robust error handling.

=item *

Use the energy map to create a mask with a specified energy width.

=item *

A flag for plotting (herfd, xes, and map)

=item *

Scan file format is currently hardwired.  In the future, will need to
adapt to different columns.

=item *

In the future, will need a more sophisticated mechanism for relating
C<stub> to scan file and to image files -- some kind of templating
scheme, I suspect

=item *

Other energy map output formats.  A gif would be useful.

=item *

bin with 2x2 or 3x3 bins

=item *

MooseX::MutatorAttributes or MooseX::GetSet would certainly be nice....

=item *

It should not be necessary to specify the list of elastic energies in
the config file.  They could be culled from the file names.

=item *

Figure out element and emission line by comparing the midpoint of the
range of elastic energies to a table of line energies.

=item *

Use of XDI is undocumented.

=item *

Wouldn't it be awesome to have all the data&images stored in an HDF5
file?

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

This software was created with advice from and in collaboration with
Jeremy Kropf (kropf AT anl DOT gov)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
