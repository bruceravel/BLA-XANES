package Xray::BLA;
use Xray::BLA::Return;

use Statistics::Descriptive;
use Xray::Absorption;

use version;
our $VERSION = version->new('1');

use Moose;
with 'Xray::BLA::Tools';
with 'Xray::BLA::Image';
with 'Xray::BLA::Mask';
with 'Xray::BLA::IO';
with 'Xray::BLA::Pause';
with 'Xray::BLA::Plot';

with 'Demeter::Project';

use MooseX::Aliases;
use Moose::Util::TypeConstraints;

use PDL::Lite;
use PDL::NiceSlice;
use PDL::IO::Pic qw(wim rim);
use PDL::IO::Dumper;

use File::Copy;
use File::Path;
use File::Spec;
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

my @line_list = @{$$Xray::Absorption::Elam::r_elam{sorted}};


##with 'MooseX::MutatorAttributes';
##with 'MooseX::SetGet';		# this is mine....

enum 'BlaModes' => [qw(cli wx)];
coerce 'BlaModes',
  from 'Str',
  via { lc($_) };
has 'ui'                 => (is => 'rw', isa => 'BlaModes', default => q{cli},
			     documentation => "The user interaction mode of the current program, currently cli or wx.");
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
has 'tiffcounter'      	 => (is => 'rw', isa => 'Str', default => q{00001},
			     documentation => "The counter part of the elastic tiff image name.");
has 'energycounterwidth' => (is => 'rw', isa => 'Str', default => 5,
			     documentation => "The width of the energy counter part of the energy tiff image name.");
has 'outfolder'		 => (is => 'rw', isa => 'Str', default => q{},
			     trigger => sub{my ($self, $new) = @_; mkpath($new) if not -d $new;},
			     documentation => "The location on disk to which processed data and images are written.");
has 'cleanup'		 => (is => 'rw', isa => 'Bool', default => 0,
			     documentation => "A flag for removing outfolder when the process finishes -- should be 0 for CLI and 1 for GUI.");
has 'outimage'           => (is => 'rw', isa => 'Str', default => q{gif},
			     documentation => "The default output image type, typically either gif or tif.");

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
has 'deltae'	         => (is => 'rw', isa => 'Num', default => 1,
			     documentation => "The width in eV about the emission energy for creating a mask from the energy map.");
has 'npixels'            => (is => 'rw', isa => 'Int', default => 0,
			     documentation => "The number of illuminated pixels in the final mask.");
has 'nbad'               => (is => 'rw', isa => 'Int', default => 0,
			     documentation => "The number of bad pixels found in the elastic image.");

has 'radius'             => (is => 'rw', isa => 'Int', default => 2,
			     documentation => "The radius used for the areal mean/median step of mask creation.");
has 'scalemask'          => (is => 'rw', isa => 'Num', default => 1,
			     documentation => "The value by which to multiply the mask during the multiplication step of mask creation.");
has 'nsmooth'            => (is => 'rw', isa => 'Int', default => 4,
			     documentation => "The number of repotition of the three-point smoothing used in energy map creation.");

has 'imagescale'         => (is => 'rw', isa => 'Num', default => 40,
			     documentation => "A scaling factor for the color scale when plotting images.  A bigger number leads to a smaller range of the plot.");

#enum 'Xray::BLA::Projections' => ['median', 'mean'];
#coerce 'Xray::BLA::Projections',
#  from 'Str',
#  via { lc($_) };
has 'operation'          => (is => 'rw', isa => 'Str', default => q{median},
			     documentation => "The areal operation, either median or mean.");

has 'elastic_file'       => (is => 'rw', isa => 'Str', default => q{},
			     documentation => "The fully resolved file name containing the measured elastic image.");
has 'elastic_image'      => (is => 'rw', isa => 'PDL', default => sub {PDL::null},
			     documentation => "The PDL object containing the elastic image.",
			     trigger => sub{my ($self, $new) = @_; my $max = $new->flat->max; $self->eimax($max)} );
has 'eimax'              => (is => 'rw', isa => 'Num', default => 0,
			     documentation => "unit pixel size in mask");


# has 'bad_pixel_list' => (
# 			 traits    => ['Array'],
# 			 is        => 'rw',
# 			 isa       => 'ArrayRef',
# 			 default   => sub { [] },
# 			 handles   => {
# 				       'push_bad_pixel_list'  => 'push',
# 				       'pop_bad_pixel_list'   => 'pop',
# 				       'clear_bad_pixel_list' => 'clear',
# 				      },
# 			 documentation => "An array reference containing the x,y coordinates of the bad pixels."
# 			);
has 'bad_pixel_mask'   => (is => 'rw', isa => 'PDL', default => sub {PDL::null},
			   documentation => "The PDL object containing the bad pixel mask.");

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

has 'scan_file_list' => (
			    traits    => ['Array'],
			    is        => 'rw',
			    isa       => 'ArrayRef',
			    default   => sub { [] },
			    handles   => {
					  'push_scan_file_list'  => 'push',
					  'pop_scan_file_list'   => 'pop',
					  'clear_scan_file_list' => 'clear',
					 },
			    documentation => "An array reference containing the fully resolved file names of the measured images at every energy point in a scan."
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

#has 'gp' => (is => 'rw', isa => 'Graphics::GnuplotIF', default => sub{Graphics::GnuplotIF->new(style => 'lines')});
has 'xdata' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_xdata'  => 'push',
			      'pop_xdata'   => 'pop',
			      'clear_xdata' => 'clear',
			     },
		documentation => "An array reference containing the x-axis data for plotting."
	       );
has 'ydata' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_ydata'  => 'push',
			      'pop_ydata'   => 'pop',
			      'clear_ydata' => 'clear',
			     },
		documentation => "An array reference containing the y-axis data for plotting."
	       );
has 'mudata' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_mudata'  => 'push',
			      'pop_mudata'   => 'pop',
			      'clear_mudata' => 'clear',
			     },
		documentation => "An array reference containing the conventional mu(E) for plotting."
	       );

has 'sentinal'  => (traits  => ['Code'],
		    is => 'rw', isa => 'CodeRef', default => sub{sub{1}},
		    handles => {call_sentinal => 'execute',});

#enum 'Xray::BLA::Backends' => ['Imager', 'Image::Magick', 'ImageMagick'];
#has 'backend'	=> (is => 'rw', isa => 'Str', default => q{Imager},
#		    documentation => 'The tiff reading backend, usually Imager, possible Image::Magick.');

sub import {
  my ($class) = @_;
  strict->import;
  warnings->import;
};

sub DEMOLISH {
  my ($self) = @_;
  return $self if not $self->cleanup;
  my $err;
  rmtree($self -> outfolder, {error=>\$err}) if -d $self->outfolder;
  #print $err, $/ if $err;
  return $self;
};

sub report {
  my ($self, $string, $color) = @_;
  my $toscreen = ($self->colored) ? Term::ANSIColor::colored($string, $color) : $string;
  return $toscreen.$/;
};


##################################################################################
## initialization file
##################################################################################

sub read_ini {
  my ($self, $configfile) = @_;

  tie my %ini, 'Config::IniFiles', ( -file => $configfile );

  $self -> scanfolder ($ini{measure}{scanfolder})      if exists($ini{measure}{scanfolder});
  $self -> tifffolder ($ini{measure}{tiffolder})       if exists($ini{measure}{tiffolder});
  $self -> tiffcounter($ini{measure}{tiffcounter})     if exists($ini{measure}{tiffcounter});
  $self -> energycounterwidth($ini{measure}{energycounterwidth}) if exists($ini{measure}{energycounterwidth});
  $self -> outfolder  ($ini{measure}{outfolder})       if exists($ini{measure}{outfolder});
  $self -> element    ($ini{measure}{element})         if exists($ini{measure}{element});
  $self -> line	      ($ini{measure}{line})            if exists($ini{measure}{line});

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
 EMISSION: {

    ($list[1] eq 'to') and do {	# <start> to <end> by <step>
      my $eee = $list[0];	#    0     1   2    3    4
      push @elastic, $eee;
      while ($eee < $list[2]) {
	$eee += $list[4];
	push @elastic, $eee;
      };
      last EMISSION;
    };

    ($list[1] =~ m{\d+}) and do { # list of energies
      @elastic = @list;
      last EMISSION;
    };

    @elastic = @list;

  };
  return \@elastic;
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


sub guess_element_and_line {
  my ($self) = @_;
  my $stat = Statistics::Descriptive::Full->new();
  foreach my $e (@{$self->elastic_energies}) {
    $stat->add_data($e);
  };

  my ($med, $diff, $el, $li) = ($stat->median, 999999, q{}, q{});
  foreach my $l (@line_list) {
    if (abs($l->[2] - $med) < $diff) {
      $diff = abs($l->[2] - $med);
      $el = ucfirst($l->[0]);
      $li = ucfirst($l->[1]);
    };
  };
  return ($el, $li);
};

sub read_mask {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  my $ret = Xray::BLA::Return->new;
  my $fname = $self->mask_file("mask", $self->outimage);
  if (not -e $fname) {
    $ret->status(0);
    $ret->message("mask file $fname does not exist");
    return $ret;
  };
  my $image = rim($fname);
  $self -> elastic_image($image);
  print $self->report("Read mask from ".$fname, 'yellow') if $args{verbose};
  return $ret;
};



sub apply_mask {
  my ($self, $tif, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{silence} ||= 0;
  my $ret = Xray::BLA::Return->new;
  local $|=1;

  my $image;
  if ($self->scan_file_list) {
    $image = $self->scan_file_list->[$tif-1];
  } else {
    my $pattern = '%s_%' . $self->energycounterwidth . '.' . $self->energycounterwidth . 'd.tif';
    my $fname = sprintf($pattern, $self->stub, $tif);
    $image = File::Spec->catfile($self->tiffolder, $fname);
  };
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
    my $masked = $self->elastic_image * $self->Read($image);
    #my $sum = int($masked->flat->sumover->sclr / $self->eimax);
    my $sum = int($masked->sum / $self->eimax);
    printf("  %7d\n", $sum) if ($args{verbose} and (not $tif % 10));
    $ret->status($sum);
  };
  return $ret;
};


# # HERFD scan on Au3MarineCyanos1
# # ----------------------------------
# # energy time ring_current i0 it ifl ir roi1 roi2 roi3 roi4 tif
#     11850.000   20  95.3544291727  1400844   830935   653600   956465      38      18      15      46      1
sub scan {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{xdiini}  ||= q{};
  my $ret = Xray::BLA::Return->new;
  local $|=1;
  $self->clear_xdata;
  $self->clear_ydata;

  my (@data, @point);

  my $i = 1;
  print $self->report("Reading scan from ".$self->scanfile, 'yellow') if $args{verbose};
  open(my $SCAN, "<", $self->scanfile);
  while (<$SCAN>) {
    next if m{\A\#};
    next if m{\A\s*\z};
    chomp;
    @point = ();
    my @list = split(" ", $_);

    $self->call_sentinal($list[-1]) if not ($i % 30);
    my $loop = $self->apply_mask($list[11], verbose=>$args{verbose});
    push @point, $list[0];
    push @point, sprintf("%.10f", $loop->status/$list[3]);
    push @point, @list[3..6];
    push @point, $loop->status;
    push @point, @list[1..2];
    push @data, [@point];
    $self->push_xdata($point[0]);
    $self->push_ydata($point[1]);
    $self->push_mudata(log($point[2]/$point[3]));
    ++$i;
  };
  close $SCAN;

  my $outfile;
  if (($XDI_exists) and (-e $args{xdiini})) {
    $outfile = $self->xdi_out($args{xdiini}, \@data);
  } else {
    $outfile = $self->dat_out(\@data);
  };

  $ret->message($outfile);
  print $self->report("Wrote $outfile", 'bold green') if $args{verbose};
  return $ret;
};



##################################################################################
## RIXS functionality
##################################################################################


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
  print $self->report("Prepared HERFD files for pixel count normalization", 'yellow') if $args{verbose};
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
  print $self->report("Wrote rixs map to $outfile", 'bold green') if $args{verbose};

  return $ret;
};



##################################################################################
## XES functionality
##################################################################################


sub compute_xes {
  my ($self, @args) = @_;
  my %args = @args;
  $args{verbose} ||= 0;
  $args{inident} ||= 0;
  my $ret = Xray::BLA::Return->new;

  $self->get_incident($args{incident});
  print $self->report("Making XES at incident energy ".$self->incident, 'yellow') if $args{verbose};

  my @values  = ();
  my @npixels = ();
  my $counter;
  $counter = Term::Sk->new('Computing XES, time elapsed: %8t %15b (emission energy %c of %m)',
			   {freq => 's', base => 0, target=>$#{$self->elastic_energies}}) if ($self->ui eq 'cli');
  foreach my $e (@{$self->elastic_energies}) {
    $counter->up if ($self->screen and ($self->ui eq 'cli'));
    $self -> energy($e);
    my $ret = $self -> read_mask(verbose=>0);
    print(0) && exit(1) if not $ret->status;
    my $value = $self->apply_mask($self->nincident, verbose=>0, silence=>1)->status;
    #my $max = $self->elastic_image->flat->max;
    my $np = int($self->elastic_image->flat->sumover->sclr);
    push @values, $value;
    push @npixels, $np/$self->eimax;
    #print "$e  $value  $np\n";
  };
  $counter->close if ($self->screen and ($self->ui eq 'cli'));
  my $max = max(@npixels);
  @npixels = map {$max / $_} @npixels;

  my @xes = ();
  foreach my $i (0 .. $#npixels) {
    push @xes, [$self->elastic_energies->[$i], $npixels[$i]*$values[$i], $npixels[$i], $values[$i], ];
  };
  my $outfile;
  if (($XDI_exists) and (-e $args{xdiini})) {
    $outfile = $self->xdi_xes($args{xdiini}, \@xes);
  } else {
    $outfile = $self->dat_xes(\@xes);
  };
  $ret->message($outfile);
  print $self->report("Wrote $outfile", 'bold green') if $args{verbose};
  return $ret;
};


######################################################################
#### debuging tools

sub attribute_report {
  my ($self) = @_;
  my @list = $self->meta->get_attribute_list;
  my $text = q{};
  foreach my $a (sort @list) {
    my $this = $self->$a;
    $this = join("  ;  ", @{$this}) if ($a eq 'steps');
    $text .= sprintf "%-20s : %s\n", $a, $this;
  };
  return $text;
};



__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Xray::BLA - Convert bent-Laue analyzer + Pilatus 100K data to a XANES spectrum

=head1 VERSION

1

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
F<Aufoil_elastic_EEEE_#####.tif> where C<EEEE> is the incident energy
and C<#####> is the numeric counter for the tiff images.  For
instance, an exposure at the peak of the gold Lalpha1 line would be
called F<Aufoil_elastic_9713_00001.tif>.

If you use a different naming convention, this software in its current
form B<will break>!  See L</"BUGS AND LIMITATIONS">.

This software also makes assumptions about the content of the scan
file.  The columns are expected to come in a certain order.  If the
order of columns chnages, the HERFD will still be measured and
recorded properly, but the remaining columns in the output files may
be misidentified.  If the first column is not energy, all bets are
off.

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

=item C<tiffcounter>

The counter appended to the name of each tiff image.  By default the
EPICS camera interface appends C<#####> to the tiff filename.  Since
one image is measured at each energy, C<00001> is appended, resulting
in a name like F<Aufoil1_elastic_9713_00001.tif>.  If you have
configured the camserver to use a different length string or had you
data acquisition software use a different string altogether, you can
specify it with this attribute.  Note, though, that this software is
not very clever about these file names -- it makes strict assumptions
about the format of the tif file name.

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

This contains the PDL of the elastic image.

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

See L<Xray::BLA::Mask>

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

See L<Xray::BLA::Mask> for details about the mask generation steps.

=over 4

=item C<check>

Confirm that the scan file and elastic image taken from the values of
C<stub> and C<energy> exist and can be read.

This is the first thing done by the C<mask> method and must be the
initial chore of any script using this library.

  $spectrum -> check;

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

L<PDL>, L<PDL::IO::FlexRaw>, L<PDL::IO::Pic>,
L<PDL::Graphics::Simple>, L<PDL::Graphics::Gnuplot>

=item *

L<Moose>, L<MooseX::AttributeHelpers>, L<MooseX::Aliases>

=item *

L<Math::Round>

=item *

L<Config::IniFiles>

=item *

L<Term::Sk>

=item *

L<Text::Template>

=item *

L<Xray::XDI>  (optional)

=back

=head1 BUGS AND LIMITATIONS

See F<todo.org>

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
