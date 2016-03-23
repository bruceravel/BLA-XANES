..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


A HERFD measurement
===================

Here is an example of a high energy resolution fluorescence detection
(HERFD) measurement of the Pt L\ :sub:`III` edge using the L\ |alpha|\
:sub:`1` emission line.  This animationmontage shows a sequence of 112
exposures of the Pilatus through the energy range of the Pt L\
:sub:`III` XANES measurement.

.. figure:: ../_images/herfd_montage.png
   :target: ../_images/herfd_montage.png
   :width: 40%
   :align: center

   The HERFD measurement sequence for the Pt L\ :sub:`III` edge using
   the L\ |alpha|\ :sub:`1` emission line.

At some level, it is clear how this is a XANES spectrum.  The first
few exposures are below the edge.  There is no fluorescence below the
edge, so there little signal on the face of the detector.  As the
monochromator is scanned above the edge, the signal on the detector
grows.  Through the XAFS oscillations, the intensity of the signal on
the detector varies.

To convert these images into a spectrum, it is necessary to create a
map which translates a pixel location on the detector into an energy.
That is, the crystal disperses energy over the face of the detector.
To compute the HERFD signal, we want to include only that portion of
each image which corresponds to a narrow energy band around the L\
|alpha|\ :sub:`1` peak energy of 9442 eV.

To do this, we measure an :quoted:`elastic image` at 9442 eV.  The
elastically scattered photons at this energy are dispersed by the Laue
analyzer onto specific pixels of the detector.  These images are used
to make a mask that associates those illuminated pixels with the
energy 9442 eV.


.. figure:: ../_images/elastic_9442.png
   :target: ../_images/elastic_9442.png
   :width: 40%
   :align: center

   The measurement of the elastic scattering at 9442 eV, the peak of
   the L\ |alpha|\ :sub:`1` emission line.

The mask creation algorithm has a lot to deal with, as you can see
from the elastic montage.  The mask creation has to reject weakly
illuminated pixels on the periphery of each image, leaving only the
wiggly stripe running through the middle of the each image.  It also
must reject very bright spots due to to powder diffraction, which
occasionally occur and are often much brighter than the rest of the
image.

Here is the mask generated from the elastic image at 9442 eV.
The algorithm isolates those pixels which are obviously within the
stripes of the elastic images, setting each of those pixels to 1,
while setting all other pixels to 0.

.. figure:: ../_images/mask_9442.png
   :target: ../_images/mask_9442.png
   :width: 40%
   :align: center

   The mask for 9442 eV, the peak of the L\ |alpha|\ :sub:`1` emission
   line.


This mask is then applied in sequence to the images measured
throughout the range of the Pt L\ :sub:`III` edge XANES.  This is done
by multiplying the mask pixel-by-pixel with each measurement in the
scan.  This extracts only those pixels associated with the peak of the
L\ |alpha|\ :sub:`1` emission line.

The intensity of the masked pixels are summed, yielding the HERFD
signal at that energy.  This is repeated for each energy point,
yielding the HERFD spectrum.

.. figure:: ../_images/herfd_9442.png
   :target: ../_images/herfd_9442.png
   :width: 40%
   :align: center

   The HERFD using the 9442 eV mask.
