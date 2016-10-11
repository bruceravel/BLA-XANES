#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build
  -> new(
	 module_name        => 'Xray::BLA',
	 create_readme      => 0,
	 license            => 'perl',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 requires           => {
				'perl'                      => '5.10.0',
				'PDL'                       => '0',
				'PDL::IO::HDF5'             => '0.73',
				'Moose'			    => '1.21',
				'MooseX::Aliases'           => '0',
				'Config::IniFiles'          =>  0,
				'Image::Info'               =>  1.38,
				'File::Slurper'             =>  0,
				'List::Compare'             =>  0,
				'Math::Random'              =>  0,
				'Math::Round'               =>  0,
				#'Xray::XDI'                 => 0,
				'Term::Sk'                  => '0.07',
				'Text::Template'            =>  0,
				'YAML::Tiny'                =>  0,
				'Graphics::Gnuplot::Palettes' => 0,
			       },
	 recommends         => {
				'PDL::Graphics::Simple'     =>  0,
				'PDL::Graphics::Gnuplot'    =>  '2.006',
				'Pod::POM::View::Restructured' => 0,
	 		       },
	 sign               => 1,
	);
$build->add_build_element('demeter_conf');
$build->add_build_element('ico');
$build->add_build_element('ini');
$build->add_build_element('png');
$build->create_build_script;


## redefine (and suppress the warning about doing so) the methods used
## to generate the bat files.  this adds code for redirecting STDOUT
## and STDERR to a log file in %APPDATA%\demeter and for verifying
## that %APPDATA%\demeter actually exists

package Module::Build::Platform::Windows;

{
  use Config;
  no warnings 'redefine';
  sub make_executable {
    my $self = shift;

    $self->SUPER::make_executable(@_);

    foreach my $script (@_) {
      my @list = split(/\\/, $script);
      my $this = $list[-1];
      # Native batch script
      if ( $script =~ /\.(bat|cmd)$/ ) {
	$self->SUPER::make_executable($script);
	next;

	# Perl script that needs to be wrapped in a batch script
      } else {
	my %opts = ();
	if ( $script eq $self->build_script ) {
	  $opts{ntargs}    = q(-x -S %0 --build_bat %*);
	  $opts{otherargs} = q(-x -S "%0" --build_bat %1 %2 %3 %4 %5 %6 %7 %8 %9);
	} else {
	  my $logfile = ' > "%APPDATA%\\demeter\\' . $this . '.log" 2>&1';
	  $opts{ntargs}    = q(-x -S %0 %*) . $logfile;
	  $opts{otherargs} = q(-x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9) . $logfile;
	};

	my $out = eval {$self->pl2bat(in => $script, update => 1, %opts)};
	if ( $@ ) {
	  $self->log_warn("WARNING: Unable to convert file '$script' to an executable script:\n$@");
	} else {
	  $self->SUPER::make_executable($out);
	}
      }
    }
  }


  # This routine was copied almost verbatim from the 'pl2bat' utility
  # distributed with perl. It requires too much voodoo with shell quoting
  # differences and shortcomings between the various flavors of Windows
  # to reliably shell out
  sub pl2bat {
    my $self = shift;
    my %opts = @_;

    # NOTE: %0 is already enclosed in doublequotes by cmd.exe, as appropriate
    $opts{ntargs}    = '-x -S %0 %*' unless exists $opts{ntargs};
    $opts{otherargs} = '-x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9' unless exists $opts{otherargs};

    $opts{stripsuffix} = '/\\.plx?/' unless exists $opts{stripsuffix};
    $opts{stripsuffix} = ($opts{stripsuffix} =~ m{^/([^/]*[^/\$]|)\$?/?$} ? $1 : "\Q$opts{stripsuffix}\E");

    unless (exists $opts{out}) {
      $opts{out} = $opts{in};
      $opts{out} =~ s/$opts{stripsuffix}$//oi;
      $opts{out} .= '.bat' unless $opts{in} =~ /\.bat$/i or $opts{in} =~ /^-$/;
    }

    ## %~dp0 will give the drive and path to the bat file being run
    ## if the bat file is C:\strawberry\perl\site\bin\dathena.bat
    ## %~dp0 = C:\strawberry\perl\site\bin\
    ## DEMETER_BASE will, therefore, be C:\strawberry
    ## presumably, all the bat files are in C:\strawberry\perl\site\bin\, so
    ##   trimming \perl\site\bin\ (which is what the following line does)
    ##   is ok
    ## then set a minimal path for running Demeter
    my $head = <<EOT;
    \@rem = '--*-Perl-*--
    \@echo off
    SET DOTDIR="%APPDATA%\\demeter"
    IF NOT EXIST %DOTDIR% MD %DOTDIR%
    SET DEMETER_BASE=%~dp0
    SET DEMETER_BASE=%DEMETER_BASE:\\perl\\site\\bin\\=%
    SET IFEFFIT_DIR=%DEMETER_BASE%\\c\\share\\ifeffit\\
    SET PATH=C:\\Windows\\system32;C:\\Windows;C:\\Windows\\System32\\Wbem;%DEMETER_BASE%\\c\\bin;%DEMETER_BASE%\\perl\\site\\bin;%DEMETER_BASE%\\perl\\bin;%DEMETER_BASE%\\c\\bin\\gnuplot\\bin
    if "%OS%" == "Windows_NT" goto WinNT
    perl $opts{otherargs}
    goto endofperl
    :WinNT
    perl $opts{ntargs}
    if NOT "%COMSPEC%" == "%SystemRoot%\\system32\\cmd.exe" goto endofperl
    if %errorlevel% == 9009 echo You do not have Perl in your PATH.
    if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
    goto endofperl
    \@rem ';
EOT

    $head =~ s/^\s+//gm;
    my $headlines = 2 + ($head =~ tr/\n/\n/);
    my $tail = "\n__END__\n:endofperl\n";

    my $linedone  = 0;
    my $taildone  = 0;
    my $linenum   = 0;
    my $skiplines = 0;

    my $start = $Config{startperl};
    $start = "#!perl" unless $start =~ /^#!.*perl/;

    my $in = IO::File->new("< $opts{in}") or die "Can't open $opts{in}: $!";
    my @file = <$in>;
    $in->close;

    foreach my $line ( @file ) {
      $linenum++;
      if ( $line =~ /^:endofperl\b/ ) {
	if (!exists $opts{update}) {
	  warn "$opts{in} has already been converted to a batch file!\n";
	  return;
	}
	$taildone++;
      }
      if ( not $linedone and $line =~ /^#!.*perl/ ) {
	if (exists $opts{update}) {
	  $skiplines = $linenum - 1;
	  $line .= "#line ".(1+$headlines)."\n";
	} else {
	  $line .= "#line ".($linenum+$headlines)."\n";
	}
	$linedone++;
      }
      if ( $line =~ /^#\s*line\b/ and $linenum == 2 + $skiplines ) {
	$line = "";
      }
    }

    my $out = IO::File->new("> $opts{out}") or die "Can't open $opts{out}: $!";
    print $out $head;
    print $out $start, ( $opts{usewarnings} ? " -w" : "" ),
      "\n#line ", ($headlines+1), "\n" unless $linedone;
    print $out @file[$skiplines..$#file];
    print $out $tail unless $taildone;
    $out->close;

    return $opts{out};
  }

}
