# NAME

Xray::BLA - Convert bent-Laue analyzer + Pilatus 100K data to a XANES spectrum

# VERSION

2

# SYNOPSIS

    use Xray::BLA; # automatically turns on strict and warnings

    my $spectrum = Xray::BLA->new;

    $spectrum->read_ini("config.ini"); # set attributes from ini file
    $spectrum->stub('myscan');
    $spectrum->energy(9713);

    $spectrum->mask(verbose=>1, write=>0, animate=>0);
    $spectrum->scan(verbose=>1);

Xray::BLA imports `warnings` and `strict` by default.

# DESCRIPTION

This module is an engine for converting a series of tiff images
collected using a bent Laue analyzer and a Pilatus 100K area detector
into a high energy resolution XANES spectrum.  A HERFD measurement
consists of a related set of files from the measurement:

1. A column data file containing the energy, signals from other scalars,
and a few other columns
2. A tiff image of an exposure at each energy point.  This image must be
interpreted to be the HERFD signal at that energy point.
3. A set of one or more exposures taken at incident energies around the
peak of the fluorescence line (e.g. Lalpha1 for an L3 edge, etc).
These exposures are used to make masks for interpreting the sequence
of images at each energy point.

Attributes for specifying the paths to the locations of the column
data files (`scanfolder`) and the tiff files (`tiffolder`,
`tifffolder` with 3 `f`'s is an alias)) are typically set from an
ini-style configuration file.

Assumptions are made about the names of the files in those
locations. Each files is built upon a stub, indicated by the `stub`
attribute.  If `stub` is "Aufoil", then the column data in
`scanfolder` file is named `Aufoil.001`.  The tiff images at each
energy point are called `Aufoil_NNNNN.tif` where `NNNNN` is the
index of the energy point.  One of the columns in the scan file
contains this index so it is unambiguous which tiff image corresponds
to which energy point.  Finally, the elastic exposures are called
`Aufoil_elastic_EEEE_#####.tif` where `EEEE` is the incident energy
and `#####` is the numeric counter for the tiff images.  For
instance, an exposure at the peak of the gold Lalpha1 line would be
called `Aufoil_elastic_9713_00001.tif`.

If you use a different naming convention, this software in its current
form **will break**!  See ["BUGS AND LIMITATIONS"](#bugs-and-limitations).

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
the perl universe that work well, [Imager](https://metacpan.org/pod/Imager) and `Image::Magick`,
although using [Image::Magick](https://metacpan.org/pod/Image::Magick) requires recompilation to be able to
use 32 bit sample depth.  Happily, [Imager](https://metacpan.org/pod/Imager) works out of the box, so
I am using it.

The signed 32 bit tiffs are imported using [Imager](https://metacpan.org/pod/Imager) and immediately
stuffed into a [PDL](https://metacpan.org/pod/PDL) object.  All subsequent work is done using PDL.

# ATTRIBUTES

- `stub`

    The basename of the scan and image files.  The scan file is called
    `<stub>.001`, the image files are called
    `<stub>_NNNNN.tif`, and the processed column data files are
    called `<stub>_<energy>.001`.

- `element`

    The element of the absorber.  This is currently only used when making
    the energy v. pixel map.  This can be a two-letter element symbol, a Z
    number, or an element name in English (e.g. Au, 79, or gold).

- `line`

    The measured emission line.  This is currently only used when making
    the energy v. pixel map.  This can be a Siegbahn (e.g. La1 or Lalpha1)
    or IUPAC symbol (e.g. L3-M5).

- `scanfile`

    The fully resolved path to the scan file, as determined from `stub`
    and `scanfolder`.

- `scanfolder`

    The folder containing the scan file.  The scan file name is
    constructed from the value of `stub`.

- `tiffolder`

    The folder containing the image files.  The image file names are
    constructed from the value of `stub`.  `tifffolder` (with 3 `f`'s)
    is an alias.

- `tiffcounter`

    The counter appended to the name of each tiff image.  By default the
    EPICS camera interface appends `#####` to the tiff filename.  Since
    one image is measured at each energy, `00001` is appended, resulting
    in a name like `Aufoil1_elastic_9713_00001.tif`.  If you have
    configured the camserver to use a different length string or had you
    data acquisition software use a different string altogether, you can
    specify it with this attribute.  Note, though, that this software is
    not very clever about these file names -- it makes strict assumptions
    about the format of the tif file name.

- `outfolder`

    The folder to which the processed file is written.  The processed file
    name is constructed from the value of `stub`.

- `energy`

    This normally takes the tabulated value of the measured fluorescence
    line.  For example, for the the gold L3 edge experiment, the L alpha 1
    line is likely used.  It's tabulated value is 9715 eV.

    The image containing the data measured from the elastic scattering
    with the incident energy at this energy will have a file name something
    like `<stub>_elsatic_<energy>_00001.tif`.

    This value can be changed to some other measured elastic energy in
    order to scan the off-axis portion of the spectrum.

    `peak_energy` is an alias for `energy`.

- `incident`

    The incident energy for an XES slice through the RIXS or for
    evaluation of single HERFD data point.  If not specified, it defaults
    to the midpoint of the energy scan.

- `nincident`

    The index of the incident energy for an XES slice through the RIXS or
    for evaluation of single HERFD data point.  If not specified, it
    defaults to the midpoint of the energy scan.

- `steps`

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
    using the specifies values for `bad_pixel_value` and
    `weak_pixel_value`, then an areal median of radius 2 will be computed.

- `operation`  \[median\]

    Setting this to "mean" changes the areal median algorithm to an areal
    mean algorithm.

- `bad_pixel_value`  \[400\]

    In the first pass over the elastic image, spuriously large pixel
    values -- presumably indicating the locations of bad pixels -- are
    removed from the image by setting them to 0.  This is the cutoff value
    above which a pixel is assumed to be a bad one.

- `weak_pixel_value` \[3\]

    In the first pass over the elastic image, small valued pixels are
    removed from the image.  These pixels are presumed to have been
    illuminated by a small number of stray photons not associated with the
    imagining of photons at the peak energy.  Pixels with fewer than this
    n umber of counts are set to 0.

- `lonely_pixel_value` \[3\]

    In the second pass over the elastic image, illuminated pixels with
    fewer than this number of illuminated neighboring pixels are removed
    from the image.  This serves the purpose of removing most stray
    pixels not associated with the main image of the peak energy.

    This attribute is ignored by the areal median/mean algorithm.

- `social_pixel_value` \[2\]

    In the third pass over the elastic image, dark pixels which are
    surrounded by larger than this number of illuminated pixels are
    presumed to be a part of the image of the peak energy.  They are given
    a value of 5 counts.  This serves the propose of making the elastic
    image a solid mask with few gaps in the image of the main peak.

    This attribute is ignored by the areal median/mean algorithm.

- `radius` \[2\]

    This determines the size of the square used in the areal median/mean
    algorithm.  A value of 1 means to use a 3x3 square, i.e. 1 pixel in
    each direction.  A value of 2 means to use a 5x5 square.  Thanks to
    PDL, the hit for using a larger radius is quite small.

- `elastic_file`

    This contains the name of the elastic image file.  It is constructed
    from the values of `stub`, `energy`, and `tiffolder`.

- `elastic_image`

    This contains the PDL of the elastic image.

- `npixels`

    The number of illuminated pixels in the mask.  That is, the number of
    pixels contributing to the HERFD signal.

- `columns`

    When the elastic file is read, this is set with the number of columns
    in the image.  All images in the measurement are presumed to have the
    same number of columns.  `width` is an alias for `columns`.

- `rows`

    When the elastic file is read, this is set with the number of rows in
    the image.  All images in the measurement are presumed to have the
    same number of rows.  `height` is an alias for `rows`.

- `colored`

    This flag should be true to write colored text to the screen when
    methods are called with the verbose flag on.

- `screen`

    This flag should be true when run from the command line so that
    progress messages are written to the screen.

# METHODS

All methods return an object of type [Xray::BLA::Return](https://metacpan.org/pod/Xray::BLA::Return).  This
object has two attributes: `status` and `message`.  A successful
return will have a positive definite `status`.  Any reporting (for
example exception reporting) is done via the `message` attribute.

Some methods, for example `apply_mask`, use the return `status` as
the sum of HERFD counts from the illuminated pixels.

## API

- `read_ini`

    Import an ini-style configuration file to set attributes of the
    Xray::BLA object.

        $spectrum -> read_ini("myconfig.ini");

- `guess_element_and_line`

    Using the median of the list of energies in the `elastic_energies`
    attribute, guess the element and line using a list of tabiulated line
    energies from [Xray::Absorption](https://metacpan.org/pod/Xray::Absorption).

        my ($el, $li) = $spectrum->guess_element_and_line;

- `mask`

    Create a mask from the elastic image measured at the energy given by
    `energy`.

        $spectrum->mask(verbose=>0, save=>0, animate=>0);

    When true, the `verbose` argument causes messages to be printed to
    standard output with information about each stage of mask creation.

    When true, the `save` argument causes a tif file to be saved at
    each stage of processing the mask.

    When true, the `animate` argument causes a properly scaled animation
    to be written showing the stages of mask creation.

    These output image files are gif.

    This method is a wrapper around the contents of the `step` attribute.
    Each entry in `step` will be parsed and executed in sequence.

    See [Xray::BLA::Mask](https://metacpan.org/pod/Xray::BLA::Mask)

- `scan`

    Rewrite the scan file with a column containing the HERFD signal as
    computed by applying the mask to the image file from each data point.

        $spectrum->scan(verbose=>0, xdiini=>$inifile);

    When true, the `verbose` argument causes messages to be printed to
    standard output about every data point being processed.

    The `xdiini` argument takes the file name of an ini-style
    configuration file for XDI metadata.  If no ini file is supplied, then
    no metadata and no column labels will be written to the output file.

    An [Xray::BLA::Return](https://metacpan.org/pod/Xray::BLA::Return) object is returned.  Its `message` attribute
    contains the fully resolved file name for the output HERFD data file.

- `energy_map`

    Read the masks from each emission energy and interpolate them to make
    a map of pixel vs. energy.  This requires that each mask has already
    been generated from the measured elastic image.

        $spectrum -> energy_map(verbose => 1, animate=>0);

    When true, the `verbose` argument causes messages to be printed to
    standard output about file written.

    When true, the `animate` argument causes an animated gif file to be
    written containing a movie of the processed elastic masks.

    The returned [Xray::BLA::Return](https://metacpan.org/pod/Xray::BLA::Return) object conveys no information at
    this time.

- `compute_xes`

    Take an XES slice through the RIXS map.  Weight the signal at each
    emission energy by the number of pixels illuminated in that mask.

        $spectrum->scan(verbose=>0, xdiini=>$inifile, incident=>$incident);

    The `incident` argument specifies the incident energy of the slice.
    If not given, use the midpoint (by index) of the energy array.  If an
    small integer is given, use that incident energy point.  If an energy
    value is given, use that energy or the nearest larger energy.

    When true, the `verbose` argument causes messages to be printed to
    standard output about file written.

    The returned [Xray::BLA::Return](https://metacpan.org/pod/Xray::BLA::Return) object conveys no information at
    this time.

- `get_incident`

    Given an integer (representing a data point index) or an energy value,
    set the `incident` and `nincident` attributes with the matching
    energy and index values of that point.

        $spectrum->get_incident($point);

    If `$point` is omitted, the `incident` and `nincident` attributes
    are set with the values of the midpoint (by index) of the data range.

## Internal methods

All of these methods return a [Xray::BLA::Return](https://metacpan.org/pod/Xray::BLA::Return) object, which has
two attributes, and integer `status` to indicate the return status (1
is normal in all cases here) and an string `message` containing a
short description of the exception (an empty string indicates no
exception).

See [Xray::BLA::Mask](https://metacpan.org/pod/Xray::BLA::Mask) for details about the mask generation steps.

- `check`

    Confirm that the scan file and elastic image taken from the values of
    `stub` and `energy` exist and can be read.

    This is the first thing done by the `mask` method and must be the
    initial chore of any script using this library.

        $spectrum -> check;

- `apply_mask`

    Apply the mask to the image for a given data point to obtain the HERFD
    signal for that data point.

        $spectrum -> apply_mask($tif_number, verbose=>1)

    The `status` of the return object contains the photon count from the
    image for this data point.

# MASK SPECIFICATION SYNTAX

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

- `bad # weak #`

    This specification says to remove bad and weak pixels from the image.
    The first number is the value used for `bad_pixel_value`.  The second
    number is the value used for `weak_pixel_value`.

- `multiply by #`

    This specification says to multiply the image by a constant.  That is,
    each pixel will be multiplied by the given constant.

- `areal [median|mean] radius #`

    Apply the areal median or mean algorithm.  The number specifies the
    "radius" over which to apply the median or mean.  A value of 1 says to
    construct a 3x3 square, i.e. 1 pixel both ways in both dimensions, a
    value of 2 says to construct a 5x5 square, and so on.  Using this
    algorithm, the pixel is set to either the median or the mean of the
    pixels in the square.

- `lonely #`

    Turn off a pixel that is not surrounded by enough illuminated pixels.
    The purpose of this is to darken isolated pixels.  The number is used
    as the value of `lonely_pixel_value`.  If a pixel is illuminated and
    is surrounded by fewer than that number of pixels, it will be turned
    off.

- `social #`

    Turn off a pixel that is surrounded by enough illuminated pixels.  The
    purpose of this is to illuminate dark pixels in an illuminated region.
    The number is used as the value of `social_pixel_value`.  If a pixel
    is not illuminated and is surrounded by more than that number of pixels,
    it will be turned on.

- `entire image`

    Set all pixels in the image to 1.  That is, use all the pixels in a
    image to generate the XANES value.  This is mostly used for testing
    purposes and its incompatible with any of the other steps except the
    bad pixel pass.  To examine the XANES form the entire image, use this

        [steps]
        steps = <<END
        bad 400 weak 0
        entire image
        END

The steps can be specified in any order and repeated as necessary.

The `steps` attribute is set is a configuration file containing the
`[steps]` group is read.  The `steps` attribute can be manipulated
by hand:

    $spectrum->steps(\@list_of_steps);      # set the steps to an array

    $spectrum->push_steps("multiply by 7"); # add to the end of the list of steps

    $spectrum->pop_steps;                   # remove the last item from the list

    $spectrum->steps([]); # or
    $spectrum->clear_steps;                 # remove all steps from the list

# ERROR HANDLING

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

The output column data file is **not** written on the fly, so a run
that dies or is halted early will probably result in no output being
written.  The save and animation images are written at the time the
message is written to STDOUT when the `verbose` switch is on.

# XDI OUTPUT

When a configuration file containing XDI metadata is used, the output
files will be written in XDI format.  This is particularly handy for
the RIXS function.  If XDI metadata is provided, then the
`BLA.pixel_ratio` datum will be written to the output file.  This
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
values as importance or plot multiplier values if the [Xray::XDI](https://metacpan.org/pod/Xray::XDI)
module is available.

# CONFIGURATION AND ENVIRONMENT

Using the script in the `bin/` directory, file locations, elastic
energies, and mask parameters are specified in an ini-style
configuration file.  An example is found in `share/config.ini`.

If using [Xray::XDI](https://metacpan.org/pod/Xray::XDI), metadata can be supplied by an ini-style file.
And example is found in `share/bla.xdi.ini`.

# DEPENDENCIES

This requires perl 5.10 or later.

## CPAN

- [PDL](https://metacpan.org/pod/PDL), [PDL::IO::FlexRaw](https://metacpan.org/pod/PDL::IO::FlexRaw), [PDL::IO::Pic](https://metacpan.org/pod/PDL::IO::Pic),
[PDL::Graphics::Simple](https://metacpan.org/pod/PDL::Graphics::Simple), [PDL::Graphics::Gnuplot](https://metacpan.org/pod/PDL::Graphics::Gnuplot)
- [Moose](https://metacpan.org/pod/Moose), [MooseX::AttributeHelpers](https://metacpan.org/pod/MooseX::AttributeHelpers), [MooseX::Aliases](https://metacpan.org/pod/MooseX::Aliases)
- [Math::Round](https://metacpan.org/pod/Math::Round)
- [Config::IniFiles](https://metacpan.org/pod/Config::IniFiles)
- [Term::Sk](https://metacpan.org/pod/Term::Sk)
- [Text::Template](https://metacpan.org/pod/Text::Template)
- [Xray::XDI](https://metacpan.org/pod/Xray::XDI)  (optional)

# BUGS AND LIMITATIONS

See `todo.org`

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

# AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

[http://cars9.uchicago.edu/~ravel/software/](http://cars9.uchicago.edu/~ravel/software/)

# LICENCE AND COPYRIGHT

Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlgpl](https://metacpan.org/pod/perlgpl).

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
