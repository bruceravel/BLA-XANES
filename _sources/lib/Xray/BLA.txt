.. highlight:: perl


#########
Xray::BLA
#########

****
NAME
****


Xray::BLA - Convert bent-Laue analyzer + Pilatus 100K data to XANES and XES spectrum


*******
VERSION
*******


3


********
SYNOPSIS
********



.. code-block:: perl

    use Xray::BLA; # automatically turns on strict and warnings
 
    my $spectrum = Xray::BLA->new;
 
    $spectrum->read_ini("config.ini"); # set attributes from ini file
    $spectrum->stub('myscan');
    $spectrum->energy(9713);
 
    $spectrum->mask(verbose=>1, write=>0, animate=>0);
    $spectrum->scan(verbose=>1);


Xray::BLA imports \ ``warnings``\  and \ ``strict``\  by default.


***********
DESCRIPTION
***********


This module is an engine for converting a series of tiff images
collected using a bent Laue analyzer and a Pilatus 100K area detector
into high energy resolution XANES spectra, X-ray emission spectra, or
measurements of the RIXS plane.

All measurements require a set of one or more exposures taken at
incident energies around the peak of the fluorescence line
(e.g. Lalpha1 for an L3 edge, etc).  These exposures are used to make
masks for interpreting the sequence of images at each energy point.

A HERFD measurement also consists of a related set of files from the
measurement:


1.
 
 A column data file containing the energy, signals from other scalars,
 and a few other columns
 


2.
 
 A tiff image of an exposure at each energy point.  This image must be
 interpreted to be the HERFD signal at that energy point.
 


3.



An XES measurement also consists of one or more images measured at an
energy above the absorption edge and interpreted as the non-resonant
emission spectrum.

A RIXS measurement consists of a sequence of images around the
absorption edge.  This sequence may be the same as the sequence of
elastic images.

Attributes for specifying the paths to the locations of the column
data files (\ ``scanfolder``\ ) and the tiff files (\ ``tiffolder``\ ,
\ ``tifffolder``\  with 3 \ ``f``\ 's is an alias) are typically set from an
ini-style configuration file.

The names of the image files must follow some sort of pattern so that
the software can interpret the images in terms of incident and
emission energies.  These patterns are somewhat flexible, involving
simple, user-settable file name templates.

For HERFD measurements, this software makes assumptions about the
content of the scan file.  The columns are expected to come in a
certain order.  If the order of columns chnages, the HERFD will still
be measured and recorded properly, but the remaining columns in the
output files may be misidentified.  If the first column is not energy,
all bets are off.

The Pilatus writes strange, signed 32-bit tiff files.  Importing these
is not obvious.  See Xray::BLA::Image for the details of how this is
done with PDL.


**********
ATTRIBUTES
**********


File name template attributes
=============================



\ ``stub``\ 
 
 The basename of the scan and image files.  For example, in a HERFD
 measurement, the scan file is called \ ``<stub>.001``\ , the image
 files are called \ ``<stub>_NNNNN.tif``\ , and the processed column
 data files are called \ ``<stub>_<energy>.001``\ .
 


\ ``scan_file_template``\  [%s.001]
 
 A pattern for computing the name of the \ ``scanfile``\  from the \ ``stub``\ .
 In the default, \ ``%s``\  is replaced by the \ ``stub``\ .
 


\ ``elastic_file_template``\  [%s_elastic_%e_%t.tif]
 
 A pattern for computing the name of the elastic images.  In the
 default, \ ``%s``\  is replaced by the \ ``stub``\ , \ ``%e``\  by the incident
 energy, and \ ``%t``\  is a counter.
 


\ ``image_file_template``\  [%s_%c.tif]
 
 A pattern for computing the name of the measurements images.  In the
 default, \ ``%s``\  is replaced by the \ ``stub``\ , and \ ``%t``\  is a counter.
 


\ ``tiffcounter``\ 
 
 The counter appended to the name of each tiff image.  By default the
 EPICS camera interface appends \ ``#####``\  to the tiff filename (although
 that is user-serviceable).  Since one image is measured at each
 energy, \ ``00001``\  is appended, resulting in a name like
 \ *Aufoil1_elastic_9713_00001.tif*\ .  If you have configured the
 camserver to use a different length string or had you data acquisition
 software use a different string altogether, you can specify it with
 this attribute.  The patterns in \ ``elastic_file_template``\  or
 \ ``image_file_template``\  will use this as the width of this field. This
 can be specified in the ini file.
 


\ ``energycounterwidth``\ 
 
 The width of the energy counter part of the energy tiff image name.
 



IO attributes
=============



\ ``task``\ 
 
 The task currently being performed.  This is one of \ ``herfd``\ , \ ``rixs``\ ,
 \ ``point``\ , \ ``map``\ , \ ``mask``\ , \ ``xes``\ , or \ ``plane``\ , with a few more
 possibilities use at the command line for debugging or development.
 


\ ``ui``\ 
 
 The user interaction mode, likely one of \ ``cli``\  or \ ``wx``\ .
 


\ ``element``\ 
 
 The element of the absorber.  This is currently used when plotting and
 when making the energy v. pixel map.  This can be a two-letter element
 symbol, a Z number, or an element name in English (e.g. Au, 79, or
 gold).
 


\ ``line``\ 
 
 The measured emission line.  This is used when plotting and when
 making the energy v. pixel map.  This can be a Siegbahn (e.g. La1 or
 Lalpha1) or IUPAC symbol (e.g. L3-M5).
 


\ ``scanfile``\ 
 
 The fully resolved path to the scan file, as determined from \ ``stub``\ 
 and \ ``scanfolder``\ .  This is typically computed from
 \ ``scan_file_template``\ .
 


\ ``scanfolder``\ 
 
 The folder containing the scan file.  This can be specified in the ini
 file.
 


\ ``tiffolder``\ 
 
 The folder containing the image files.  The image file names are
 constructed from the value of \ ``elastic_file_template``\  or
 \ ``image_file_template``\ .  \ ``tifffolder``\  (with 3 \ ``f``\ 's) is an alias.
 


\ ``outfolder``\ 
 
 The folder where output images and spectra are written.
 


\ ``outimage``\  [gif]
 
 The format of output images, usually one of \ ``gif``\ , \ ``png``\ , or \ ``tif``\ .
 


\ ``elastic_energies``\ 
 
 A reference to a list of energy values at which elastic images were
 measured.
 


\ ``elastic_file_list``\ 
 
 A reference to a list of the elastic image files found in \ ``tiffolder``\ .
 


\ ``elastic_file_list``\ 
 
 A reference to a list of PDLs containing the elastic image files found
 in \ ``tiffolder``\ .
 


\ ``scan_file_list``\ 
 
 A reference to a list of the measurement image files found in
 \ ``tiffolder``\ .
 


\ ``cleanup``\  [false]
 
 A flag indicating whether to remove \ ``outfolder``\  before exiting the
 program.
 


\ ``energy``\ 
 
 This normally takes the tabulated value of the measured fluorescence
 line.  For example, for the the gold L3 edge experiment, the L alpha 1
 line is likely used.  It's tabulated value is 9715 eV.
 
 The image containing the data measured from the elastic scattering
 with the incident energy at this energy might have a file name
 something like \ *<stub>_elsatic_<energy>_00001.tif*\ 
 and can be set using \ ``image_file_template``\ .
 
 This value can be changed to some other measured elastic energy in
 order to scan the off-axis portion of the spectrum.
 


\ ``incident``\ 
 
 The incident energy for an XES slice through the RIXS or for
 evaluation of single HERFD data point.  If not specified, it defaults
 to the midpoint of the energy scan.
 


\ ``nincident``\ 
 
 The index of the incident energy for an XES slice through the RIXS or
 for evaluation of single HERFD data point.  If not specified, it
 defaults to the midpoint of the energy scan.
 


\ ``columns``\ 
 
 When the elastic file is read, this is set with the number of columns
 in the image.  All images in the measurement are presumed to have the
 same number of columns.  \ ``width``\  is an alias for \ ``columns``\ .
 


\ ``rows``\ 
 
 When the elastic file is read, this is set with the number of rows in
 the image.  All images in the measurement are presumed to have the
 same number of rows.  \ ``height``\  is an alias for \ ``rows``\ .
 


\ ``colored``\  [true]
 
 This flag should be true to write colored text to the screen when
 methods are called with the verbose flag on.
 


\ ``screen``\ 
 
 This flag should be true when run from the command line so that
 progress messages are written to the screen.
 


\ ``incident_energies``\ 
 
 An array reference containing the incident energies of a HERFD scan.
 


\ ``herfd_file_list``\ 
 
 An array reference containing output files from a RIXS sequence.
 


\ ``herfd_pixels_used``\ 
 
 An array reference containing numbers of illuminated pixels from a RIXS sequence.
 


\ ``noscan``\ 
 
 A boolean indicating whether a scan file was written.  This is
 typically true for the HERFD and RIXS tasks and false for XES and
 plane tasks.
 


\ ``xdi_metadata_file``\ 
 
 The fully resolved path name for an ini file containing XDi metadata
 to be used in output ASCII column files.
 


\ ``sentinal``\ 
 
 A code reference used to provide feedback during particularly lengthy
 operations.  For example:
 
 
 .. code-block:: perl
 
     $spectrum->sentinal(sub{printf("Processing point %d of %d\n", $_[0], $npoints)});
 
 
 or, writing to the Metis status bar:
 
 
 .. code-block:: perl
 
     $spectrum->sentinal(sub{$app->{main}->status("Processing point ".$_[0]." of $np", 'wait')});
 
 



Mask recipe attribues
=====================



\ ``steps``\ 
 
 This contains a reference to an list of steps of a mask creation
 recipe.  For example, if the configuration file contains the
 following:
 
 
 .. code-block:: perl
 
     ## areal algorithm
     [steps]
     steps = <<END
     bad 400 weak 0
     gaussian 3.2
     END
 
 
 then the lines beginning with "bad" and "gaussian" will be the entries
 in the array, indicating that first bad and weak pixels will be
 removed using the specifies values for \ ``bad_pixel_value``\  and
 \ ``weak_pixel_value``\ , then a Gaussian blur filter with a threshold of
 \ ``gaussian_blur_value``\ .
 


\ ``bad_pixel_value``\   [400]
 
 In the first pass over the elastic image, spuriously large pixel
 values -- presumably indicating the locations of bad pixels -- are
 removed from the image by setting them to 0.  This is the cutoff value
 above which a pixel is assumed to be a bad one.
 


\ ``bad_pixel_mask``\ 
 
 A PDL containing ones for each pixel found to be a bad pixel.
 


\ ``weak_pixel_value``\  [3]
 
 In the first pass over the elastic image, small valued pixels are
 removed from the image.  These pixels are presumed to have been
 illuminated by a small number of stray photons not associated with the
 imagining of photons at the peak energy.  Pixels with fewer than this
 number of counts are set to 0.
 


\ ``width_min``\  and \ ``width_max``\  [0 and 487]
 
 The columns in the elastic image within which all elastic signal at
 all energies will be found.  Pixels outside those columns will be set
 to zero.  This is a way of suppressing obviously spurious signal.
 


\ ``spots``\ 
 
 A reference to a list of lists containing spots to be removed from
 elastic images during the bad/weak recipe step.  Each entry in the
 list is a reference to a list of 4 numbers, the elastic energy, the x
 and y coordinates of the spot, and the radius of the spot.  At that
 energy, the pixels within the radius around the (xy) coordinates will
 be set to zero.  This is mostly sued to avoid skewing the polynomial
 fits in the polyfit recipe step, but is, in general, a hands-on way of
 removing spurious pixels from the elastic images.
 
 The first entry in each list reference can be a single energy value or
 a range specified either as "emin-emax", which is an enclusive range
 over which to remove the spot, or "energy+" which removes the spot
 from the specified elastic image and from all subsequent images.
 


\ ``gaussian_blur_value``\  [2]
 
 The threshold value for keeping pixels after the Gaussian blur
 convolution.
 


\ ``shield``\  [15]
 
 The number of trailing elastic images to use when constructing shields
 for removing portions of elastic images containing signal from
 something other than the elastic scattering.  The default says to use
 the mask from 15 energy points back to make a shield for the current
 elastic energy.
 


\ ``lonely_pixel_value``\  [3]
 
 In this pass over the elastic image, illuminated pixels with fewer
 than this number of illuminated neighboring pixels are removed from
 the image.  This serves the purpose of removing most stray pixels not
 associated with the main image of the peak energy.
 
 This recipe step is deprecated in favor of the Gaussian blur.
 


\ ``social_pixel_value``\  [2]
 
 In this pass over the elastic image, dark pixels which are surrounded
 by larger than this number of illuminated pixels are presumed to be a
 part of the image of the peak energy.  They are given a value of 5
 counts.  This serves the propose of making the elastic image a solid
 mask with few gaps in the image of the main peak.
 
 This recipe step is deprecated in favor of the Gaussian blur.
 


\ ``scalemask``\ 
 
 The factor by which to multiply the mask during the multiply step.
 


\ ``operation``\   [mean]
 
 Setting this to "median" changes the deprecated areal median algorithm
 to an areal median algorithm.
 
 This recipe step is deprecated in favor of the Gaussian blur.
 


\ ``radius``\  [2]
 
 This determines the size of the square used in the areal median/mean
 algorithm.  A value of 1 means to use a 3x3 square, i.e. 1 pixel in
 each direction.  A value of 2 means to use a 5x5 square.
 
 This recipe step is deprecated in favor of the Gaussian blur.
 


\ ``deltae``\ 
 
 Energy width for mask creation when creating a mask from a pixel to
 energy map.
 


\ ``elastic_file``\ 
 
 This contains the name of the elastic image file.  It is typically
 constructed from the values of \ ``stub``\ , \ ``energy``\ , and \ ``tiffolder``\ 
 using \ ``elastic_file_template``\ .
 


\ ``elastic_file_template``\  [%s_elastic_%e_%t.tif]
 
 A pattern used to set the names of the elastic files.
 


\ ``elastic_image``\ 
 
 This contains the PDL of the elastic image.  As the mask creation
 recipe progresses, this contains the mask in its current state.
 


\ ``elastic_image``\ 
 
 This contains the PDL of the shield image.
 


\ ``npixels``\ 
 
 The number of illuminated pixels in the mask.  That is, the number of
 pixels contributing to the HERFD or XES signal.
 


\ ``nbad``\ 
 
 The number of bad pixels found in the bid pixel step.
 



Data processing attributes
==========================



\ ``div10``\  [false]
 
 When true, divide the emission energy by 10 when writing output files
 or making plots.
 


\ ``eimax``\ 
 
 Largest value found in a mask during a mask creation step.
 



Attributes related to plotting XAS-like or image data
=====================================================



\ ``terminal``\ 
 
 The Gnuplot terminal type to use.  This is likely one of \ ``qt``\ ,
 \ ``wxt``\ , \ ``x11``\ , \ ``windows``\ , or \ ``aqua``\ .
 


\ ``herfd_demeter``\ 
 
 A Demeter::Data object containing the HERFD data.
 


\ ``mue_demeter``\ 
 
 A Demeter::Data object containing the conventional XANES data, if available.
 


\ ``xdata``\ 
 
 An array reference containing the x-axis data for plotting.
 


\ ``ydata``\ 
 
 An array reference containing the y-axis data for plotting.
 


\ ``mudata``\ 
 
 An array reference containing conventional mu(E) data for plotting.
 


\ ``normpixels``\ 
 
 A normalized scaling factor representing the number of illuminated
 pixels in the final mask used for a HERFD scan or a RIXS sequence.
 


\ ``imagescale``\ 
 
 A scaling factor for the color scale when plotting images.  A bigger
 number leads to a smaller range of the plot.
 




*******
METHODS
*******


All methods return an object of type Xray::BLA::Return.  This
object has two attributes: \ ``status``\  and \ ``message``\ .  A successful
return will have a positive definite \ ``status``\ .  Any reporting (for
example exception reporting) is done via the \ ``message``\  attribute.

Some methods, for example \ ``apply_mask``\ , use the return \ ``status``\  as
the sum of HERFD counts from the illuminated pixels.

API
===



\ ``read_ini``\ 
 
 Import an ini-style configuration file to set attributes of the
 Xray::BLA object.
 
 
 .. code-block:: perl
 
    $spectrum -> read_ini("myconfig.ini");
 
 


\ ``guess_element_and_line``\ 
 
 Using the median of the list of energies in the \ ``elastic_energies``\ 
 attribute, guess the element and line using a list of tabiulated line
 energies from Xray::Absorption.
 
 
 .. code-block:: perl
 
    my ($el, $li) = $spectrum->guess_element_and_line;
 
 


\ ``mask``\ 
 
 Create a mask from the elastic image measured at the energy given by
 \ ``energy``\ .
 
 
 .. code-block:: perl
 
    $spectrum->mask(verbose=>0, save=>0, animate=>0);
 
 
 When true, the \ ``verbose``\  argument causes messages to be printed to
 standard output with information about each stage of mask creation.
 
 When true, the \ ``save``\  argument causes a tif file to be saved at
 each stage of processing the mask.
 
 When true, the \ ``animate``\  argument causes a properly scaled animation
 to be written showing the stages of mask creation.
 
 These output image files are gif.
 
 This method is a wrapper around the contents of the \ ``step``\  attribute.
 Each entry in \ ``step``\  will be parsed and executed in sequence.
 
 See Xray::BLA::Mask
 


\ ``scan``\ 
 
 Rewrite the scan file with a column containing the HERFD signal as
 computed by applying the mask to the image file from each data point.
 
 
 .. code-block:: perl
 
    $spectrum->scan(verbose=>0, xdiini=>$inifile);
 
 
 When true, the \ ``verbose``\  argument causes messages to be printed to
 standard output about every data point being processed.
 
 The \ ``xdiini``\  argument takes the file name of an ini-style
 configuration file for XDI metadata.  If no ini file is supplied, then
 no metadata and no column labels will be written to the output file.
 
 An Xray::BLA::Return object is returned.  Its \ ``message``\  attribute
 contains the fully resolved file name for the output HERFD data file.
 


\ ``energy_map``\ 
 
 Read the masks from each emission energy and interpolate them to make
 a map of pixel vs. energy.  This requires that each mask has already
 been generated from the measured elastic image.
 
 
 .. code-block:: perl
 
    $spectrum -> energy_map(verbose => 1, animate=>0);
 
 
 When true, the \ ``verbose``\  argument causes messages to be printed to
 standard output about file written.
 
 When true, the \ ``animate``\  argument causes an animated gif file to be
 written containing a movie of the processed elastic masks.
 
 The returned Xray::BLA::Return object conveys no information at
 this time.
 


\ ``compute_xes``\ 
 
 Take an XES slice through the RIXS map.  Weight the signal at each
 emission energy by the number of pixels illuminated in that mask.
 
 
 .. code-block:: perl
 
    $spectrum->scan(verbose=>0, xdiini=>$inifile, incident=>$incident);
 
 
 The \ ``incident``\  argument specifies the incident energy of the slice.
 If not given, use the midpoint (by index) of the energy array.  If an
 small integer is given, use that incident energy point.  If an energy
 value is given, use that energy or the nearest larger energy.
 
 When true, the \ ``verbose``\  argument causes messages to be printed to
 standard output about file written.
 
 The returned Xray::BLA::Return object conveys no information at
 this time.
 


\ ``get_incident``\ 
 
 Given an integer (representing a data point index) or an energy value,
 set the \ ``incident``\  and \ ``nincident``\  attributes with the matching
 energy and index values of that point.
 
 
 .. code-block:: perl
 
      $spectrum->get_incident($point);
 
 
 If \ ``$point``\  is omitted, the \ ``incident``\  and \ ``nincident``\  attributes
 are set with the values of the midpoint (by index) of the data range.
 



Internal methods
================


All of these methods return a Xray::BLA::Return object, which has
two attributes, and integer \ ``status``\  to indicate the return status (1
is normal in all cases here) and an string \ ``message``\  containing a
short description of the exception (an empty string indicates no
exception).

See Xray::BLA::Mask for details about the mask generation steps.


\ ``check``\ 
 
 Confirm that the scan file and elastic image taken from the values of
 \ ``stub``\  and \ ``energy``\  exist and can be read.
 
 This is the first thing done by the \ ``mask``\  method and must be the
 initial chore of any script using this library.
 
 
 .. code-block:: perl
 
    $spectrum -> check;
 
 


\ ``apply_mask``\ 
 
 Apply the mask to the image for a given data point to obtain the HERFD
 signal for that data point.
 
 
 .. code-block:: perl
 
    $spectrum -> apply_mask($tif_number, verbose=>1)
 
 
 The \ ``status``\  of the return object contains the photon count from the
 image for this data point.
 




**************************
MASK SPECIFICATION RECIPES
**************************


The steps to mask creation are specified as recipes using a simple
imperative language.  Here's an example of specifying the steps via
the configuration file:


.. code-block:: perl

     [steps]
     steps = <<END
     bad 400 weak 0
     gaussian 3.2
     shield 15
     polyfill
     END


Each specification of a step is contained on a single line.
White space is unimportant, but spelling matters.  The parser has
little intelligence.

Main steps
==========



\ ``bad # weak #``\ 
 
 This specification says to remove bad and weak pixels from the image.
 The first number is the value used for \ ``bad_pixel_value``\ .  The second
 number is the value used for \ ``weak_pixel_value``\ .
 


\ ``gaussian #.#``\ 
 
 Apply a convolution with a kernel that approximates a Gaussian blur.
 The number is a threshold above which pixels are set to 1 and below
 which pixels are set to 0.
 


\ ``shield #``\ 
 
 Create a shield from trailing masks which is used to remove spurious
 signal from the low energy region of the elastic image due to
 fluorescence from the onset of the absorption edge.  The number is the
 how far the trailing mask is behind the current mask.  The shield is
 cumulative, that is the traling mask is added to the shield from the
 previous elastic energy.
 


\ ``polyfill``\ 
 
 After applying the Gaussian blur or some other filter (and after
 applying the shield), fit polynomials to the topmost and bottom-most
 pixels in each column of the image.  Fill in the region between the
 polynomials and us that as the mask.
 



Other steps
===========


These are other possible mask recipe steps.  Some are kept for
historical interest.


\ ``multiply by #``\ 
 
 This specification says to multiply the image by a constant.  That is,
 each pixel will be multiplied by the given constant.
 


\ ``areal [median|mean] radius #``\ 
 
 Apply the areal median or mean algorithm.  The number specifies the
 "radius" over which to apply the median or mean.  A value of 1 says to
 construct a 3x3 square, i.e. 1 pixel both ways in both dimensions, a
 value of 2 says to construct a 5x5 square, and so on.  Using this
 algorithm, the pixel is set to either the median or the mean of the
 pixels in the square.
 


\ ``lonely #``\ 
 
 Turn off a pixel that is not surrounded by enough illuminated pixels.
 The purpose of this is to darken isolated pixels.  The number is used
 as the value of \ ``lonely_pixel_value``\ .  If a pixel is illuminated and
 is surrounded by fewer than that number of pixels, it will be turned
 off.
 


\ ``social #``\ 
 
 Turn off a pixel that is surrounded by enough illuminated pixels.  The
 purpose of this is to illuminate dark pixels in an illuminated region.
 The number is used as the value of \ ``social_pixel_value``\ .  If a pixel
 is not illuminated and is surrounded by more than that number of pixels,
 it will be turned on.
 


\ ``entire image``\ 
 
 Set all pixels in the image to 1.  That is, use all the pixels in a
 image to generate the XANES value.  This is mostly used for testing
 purposes and its incompatible with any of the other steps except the
 bad pixel pass.  To examine the XANES form the entire image, use this
 
 
 .. code-block:: perl
 
      [steps]
      steps = <<END
      bad 400 weak 0
      entire image
      END
 
 



Managing the steps
==================


The steps can be specified in any order and repeated as necessary.

The \ ``steps``\  attribute is set from a configuration file containing a
\ ``[steps]``\  block.  The \ ``steps``\  attribute can be manipulated by hand:


.. code-block:: perl

    $spectrum->steps(\@list_of_steps);      # set the steps to an array
 
    $spectrum->push_steps("multiply by 7"); # add to the end of the list of steps
 
    $spectrum->pop_steps;                   # remove the last item from the list
 
    $spectrum->steps([]); # or
    $spectrum->clear_steps;                 # remove all steps from the list


The \ ``spots``\  attribute can be manipulated in similar manner.


.. code-block:: perl

    $spectrum->spots(\@list_of_spots);          # set the spots to an array
 
    $spectrum->push_spots([11235, 57, 87, 5]]); # add to the end of the list of steps
 
    $spectrum->pop_spots;                       # remove the last item from the list
 
    $spectrum->spots([]);                       # or
    $spectrum->clear_spots;                     # remove all steps from the list




**************
ERROR HANDLING
**************


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

The output column data file is \ **not**\  written on the fly, so a run
that dies or is halted early will probably result in no output being
written.  The save and animation images are written at the time the
message is written to STDOUT when the \ ``verbose``\  switch is on.


**********
XDI OUTPUT
**********


When a configuration file containing XDI metadata is used, the output
files will be written in XDI format.  This is particularly handy for
the RIXS function.  If XDI metadata is provided, then the
\ ``BLA.pixel_ratio``\  datum will be written to the output file.  This
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
values as importance or plot multiplier values if the Xray::XDI
module is available.


*****************************
CONFIGURATION AND ENVIRONMENT
*****************************


Using the script in the \ *bin/*\  directory, file locations, elastic
energies, and mask parameters are specified in an ini-style
configuration file.  An example is found in \ *share/config.ini*\ .

If using Xray::XDI, metadata can be supplied by an ini-style file.
And example is found in \ *share/bla.xdi.ini*\ .


************
DEPENDENCIES
************


This requires perl 5.10 or later -- preferably \ *much*\  later.


\*
 
 PDL, `PDL::IO::FlexRaw <https://metacpan.org/pod/PDL%3a%3aIO%3a%3aFlexRaw>`_, `PDL::IO::Pic <https://metacpan.org/pod/PDL%3a%3aIO%3a%3aPic>`_,
 `PDL::Graphics::Simple <https://metacpan.org/pod/PDL%3a%3aGraphics%3a%3aSimple>`_, `PDL::Graphics::Gnuplot <https://metacpan.org/pod/PDL%3a%3aGraphics%3a%3aGnuplot>`_,
 `PDL::Fit::Polynomial <https://metacpan.org/pod/PDL%3a%3aFit%3a%3aPolynomial>`_
 


\*
 
 Moose, `MooseX::AttributeHelpers <https://metacpan.org/pod/MooseX%3a%3aAttributeHelpers>`_, `MooseX::Aliases <https://metacpan.org/pod/MooseX%3a%3aAliases>`_
 


\*
 
 `Math::Round <https://metacpan.org/pod/Math%3a%3aRound>`_
 


\*
 
 `Config::IniFiles <https://metacpan.org/pod/Config%3a%3aIniFiles>`_
 


\*
 
 `Term::Sk <https://metacpan.org/pod/Term%3a%3aSk>`_
 


\*
 
 `Text::Template <https://metacpan.org/pod/Text%3a%3aTemplate>`_
 



********************
BUGS AND LIMITATIONS
********************


See \ *todo.org*\ 

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.


******
AUTHOR
******


Bruce Ravel (bravel AT bnl DOT gov)

`http://cars9.uchicago.edu/~ravel/software/ <http://cars9.uchicago.edu/~ravel/software/>`_


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See `perlgpl <http://perldoc.perl.org/perlgpl.html>`_.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

