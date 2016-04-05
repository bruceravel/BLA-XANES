.. highlight:: perl


###############
Xray::BLA::Mask
###############

****
NAME
****


Xray::BLA::Mask - Role containing mask creation steps


*******
VERSION
*******


See `Xray::BLA <https://metacpan.org/pod/Xray%3a%3aBLA>`_


*******
METHODS
*******


General methods
===============



\ ``mask``\ 
 
 Create a mask from the elastic image measured at the energy given by
 \ ``energy``\ .
 
 
 .. code-block:: perl
 
    $spectrum->mask(@args);
 
 
 where the arguments are given using fat commas, as in \ ``verbose=``\ 0,
 save=>0, animate=>0>.
 
 The arguments are:
 
 
 \ ``verbose``\ 
  
  When true, this causes messages to be printed to standard output with
  information about each stage of mask creation.  Only used in CLI mode.
  
 
 
 \ ``save``\ 
  
  When true, this causes an image file to be saved at each stage of
  processing the mask.  Usually only used in CLI mode.
  
 
 
 \ ``animate``\ 
  
  This causes a properly scaled animation to be written showing the
  stages of mask creation.
  
 
 
 \ ``elastic``\ 
  
  Explicitly specify a file to use as the elastic image.  In CLI mode,
  this is usually determined algorithmicly, but in Metis it is taken
  from one of the image lists on the Files page.
  
 
 
 \ ``unity``\ 
  
  ??
  
 
 
 \ ``pass``\ 
  
  This is a counter for multiple passes of the \ ``social``\  step.
  
 
 
 \ ``vertical``\ 
  
  When true, this tells the \ ``social``\  step to only consider pixels
  directly above and below.
  
 
 
 \ ``plot``\ 
  
  When true, this will generate a plot at each stage of mask creation
  along with a pause for viewing it.  This is only used in CLI mode.
  
 
 
 \ ``write``\ 
  
  When given a filename, an image file will be written at the end of a
  mask creation step.  When given a false value, the image file will be
  written.
  
 
 
 These output image files are gif on linux and tif on Windows.
 
 This method is a wrapper around the contents of the
 \ ``steps``\  attribute.  Each entry in \ ``steps``\  will be parsed and
 executed in sequence.
 


\ ``check``\ 
 
 Verify that the elastic image file exists, can be read, and be
 imported as an image file.  This sets the \ ``elastic_file``\  and
 \ ``elastic_image``\  attributes.
 


\ ``remove_bad_pixels``\ 
 
 This removes the bad pixels from the map using the
 \ ``bad_pixel_mask``\  attribute.  Some of the steps, \ ``areal``\  for example,
 can reinsert a bad pixel, so it is necessary to follow each step with
 this method to ensure that the bad pixels are not used in HERFD
 processing.
 


\ ``do_step``\ 
 
 A wrapper around the various mask processing steps.  This calls the
 various steps, manages screen messages, sets some attributes, manages
 plotting in CLI mode, and manages saving images of steps in the mask
 creation process when in CLI mode.  In Metis, this is usually called
 directly without calling the \ ``mask``\  method.
 



Methods for the steps of mask creation
======================================



\ ``bad_pixels``\ 
 
 Remove pixels that are larger than the value of the \ ``bad_pixel_value``\ 
 attribute and smaller than the \ ``weak_pixel_value``\  attribute.  This
 must be the first step in mask processing.  This also sets the
 \ ``bad_pixel_mask``\  attribute, which identifies the pixels marked as bad
 pixels.
 
 Controlling attributes: \ ``bad_pixel_value``\ , \ ``weak_pixel_value``\ 
 


\ ``gaussian_blur``\ 
 
 Apply an approximate Gaussian blur filter to the image.  Set all
 pixels above a threshold value to 1, setting all below that value to
 0.  This is a simple convolution with this kernel:
 
 
 .. code-block:: perl
 
      1   / 1 2 1 \
    ---- (  2 4 2  )
     16   \ 1 2 1 /
 
 
 The size of the threshold depends on the intensity of the relevant
 part of the image.  Very bright, spurious spots will pass through this
 filter.
 
 Controlling attribute: \ ``gaussian_blur_value``\ 
 


\ ``useshield``\ 
 
 Construct a shield used to mask out a region of the elastic image
 associated with fluorescence or some other source of signal.
 
 Shields are constructed sequentially.  The first N steps do not have a
 shield -- more specifically, the shield is empty.  The next shield
 uses the mask from N steps prior to block out this signal.  The
 following shield adds the mask from N steps back to the shield of
 the previous step.  Subsequent steps accumulate the masks from N
 steps back, adding them to their shields.
 
 All pixels under the shield are then set to 0.
 
 Controlling attribute: \ ``shield``\ 
 


\ ``polyfill``\ 
 
 After the Gaussian blur or other filtering step to remove all of the
 outlying pixels, the top-most and bottom-most pixels in each column
 are noted.  Two polynomials are fit to this collection of points, one
 to the top set and one to the bottom set.  The pixels between the two
 polynomials are turned on, yielding the final mask.
 
 Controlling attributes: none.
 


\ ``lonely_pixels``\ 
 
 Remove illuminated pixels which are not surrounded by enough other
 illuminated pixels.
 
 Controlling attribute: \ ``lonely_pixel_value``\ 
 


\ ``social_pixels``\ 
 
 Include dark pixels which are surrounded by enough illuminated pixels.
 
 Controlling attribute: \ ``social_pixel_value``\ 
 


\ ``areal``\ 
 
 At each point in the mask, assign its value to the median or mean
 value of a square centered on that point.  The size of the square is
 determined by the value of the \ ``radius``\  attribute.
 
 The median operation is not currently supported.
 
 Controlling attributes: \ ``operation``\ , \ ``radius``\ 
 


\ ``multiply``\ 
 
 Multiply the entire image by a scaling factor.
 
 Controlling attribute: \ ``scalemask``\ 
 


\ ``entire_image``\ 
 
 Set every pixel in the mask to 1.  This makes the "HERFD" using the
 entire image at each energy point.  This is used for testing and
 demonstration purposes and is not actually a useful step for making
 high energy resolution data.
 
 Controlling attributes: none
 


\ ``mapmask``\ 
 
 (coming soon)
 


\ ``andmask``\ 
 
 This is the final step in mask creation.  It sets all non-zero pixels
 to 1 so that the mask can be directly multiplied by images at each
 data point in a HERFD scan.
 
 Controlling attributes: none
 




******
AUTHOR
******


Bruce Ravel (bravel AT bnl DOT gov)

`http://github.com/bruceravel/BLA-XANES <http://github.com/bruceravel/BLA-XANES>`_


*********************
LICENCE AND COPYRIGHT
*********************


Copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf. All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See `perlgpl <http://perldoc.perl.org/perlgpl.html>`_.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

