..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


The Files tool
==============

To begin with :demeter:`metis`, fill in the box with the file stub.
Then click the :button:`Pick image folder,light` button.  This will
post the file selection dialog.  Use that to select the folder
containing the sequence of images measured at elastic and
(non-)resonant incidence energies.  

Make sure the boxes containing file name templates are filled in
correctly.  These are used to specify the patterns used for the
various files written during the measurement.  Getting these right is
an important part of organizing the entire data ensemble in an
interpretable way.

Finally, click the :button:`Fetch file lists,light` button.  This will
fill up the lists of elastic energy and measurement images.
Eventually, the lists will be filled in and :demeter:`metis` will be
ready to go.


.. figure:: ../_images/metis_files.png
   :target: ../_images/metis_files.png
   :align: center

   :demeter:`metis`, after fetching all the image files.


To aid in data visualization, the three controls at the top of the
Files page should be set correctly.  The two drop-down menus are used
to indicate the element and edge of the absorber.  You will be
prompted for this based on information gleaned from the elastic energy
file names


.. figure:: ../_images/metis_chooseline.png
   :target: ../_images/metis_chooseline.png
   :align: center

   The element and edge selection dialog.

Finally, the :guilabel:`Divide by 10` button is used to indicate how
to interpret the energy value part of the image files names.  In this
example, the elastic energies are indicated by ``189280``, ``189285``,
and so on.  These integers are the incident energy multiplied by 10,
i.e. 18928.0, 19828.5, and so on.  Clicking this button to the correct
state helps :demeter:`metis` interpret the file names correctly.

The templates used to recognize elastic and measurement images (as
well as the scan file name for ``herfd`` and ``rxes`` modes) are
simple substitution templates.

+------------+-------------------------------------------------------+-----------------------------------------+
| token      | Replacement                                           | Configuration parameter                 |
+============+=======================================================+=========================================+
| ``%s``     | file stub,  ``NbF5_Kb2`` in this example              |                                         |
+------------+-------------------------------------------------------+-----------------------------------------+
| ``%e``     | elastic energy value                                  |                                         |
+------------+-------------------------------------------------------+-----------------------------------------+
| ``%i``     | incident energy value (``rxes`` and ``herfd`` modes)  |                                         |
+------------+-------------------------------------------------------+-----------------------------------------+
| ``%t``     | tiff counter string                                   | :configparam:`metis,tiffcounter`        |
+------------+-------------------------------------------------------+-----------------------------------------+
| ``%c``     | energy counter                                        | :configparam:`metis,energycounterwidth` |
+------------+-------------------------------------------------------+-----------------------------------------+

Use the `Configuration tool <config.html>`_ to set the parameters
governing the ``%t`` and ``%c`` tokens.  If set incorrectly, the
:button:`Fetch file lists,light` button will return with an error
about not being able to find files matching the templates.

Having these file naming templates allows the user to store images
from multiple measurements in the same folder on disk.

The ``%t`` is, in practice, usually something like `0001` |nd| it is a
counter that is used by EPICS :program:`areaDetector` to number
repeated exposures of the camera.  The way the BLA spectrometer is
used, this is rarely incremented, although the number of leading zeros
might be changed.  The ``%c`` token is used in ``rxes`` and ``herfd``
modes to relate an exposure during the energy scan to the index of
that energy point in the scan file.  For ``xes`` mode, this is the
counter used for repeated exposures of the non-resonant XES image.


Once all the files have been loaded into :demeter:`metis`, click on
the Mask icon in the side bar to go to `the mask creation tool
<mask.html>`_.


Visualizing individual images
-----------------------------

Individual image files can be plotted by double clicking on a file
name in either the elastic or image file list.


.. figure:: ../_images/metis_dclick.png
   :target: ../_images/metis_dclick.png
   :align: center

   Double click on items in the lists to display the measured images.

.. subfigstart::

.. figure:: ../_images/metis_dclick_elastic.png
   :target: ../_images/metis_dclick_elastic.png
   :align: center

   Double clicking on an item in the elastic file list displays the
   raw image for that elastic measurement.

.. figure:: ../_images/metis_dclick_image.png
   :target: ../_images/metis_dclick_image.png
   :align: center

   Double clicking on an item in the image file list displays the
   raw image for that XES measurement.

.. subfigend::
   :width: 0.4
   :label: _fig-dclick



HERFD measurements
------------------

A HERFD measurement uses a scan file as well as a complete set of
elastic and image files.  Thus none of the controls for folders or
templates are disabled in HERFD mode.

.. figure:: ../_images/metis_files_herfd.png
   :target: ../_images/metis_files_herfd.png
   :align: center

   :demeter:`metis`'s files tool in HERFD mode.


In a HERFD measurement, the image file list is typically longer than
the elastic file list.  An image file must be collected at each point
in a XANES scan |nd| typically 100 or so points.  In this example,
elastic images are measured every eV from 9429 to 9454 eV, a range
that surrounds the L\ |alpha|\ :sub:`1` peak at 9442 eV.



RXES measurements
-----------------

An RXES measurement is structured a little differently from the other
measurement types.  In the case of RXES, the sequence of masks is the
same set of files as the sequence of emission measurements.  That is,
the elastic part of each image will be processed into a mask then
applied to the same sequence of images.


.. figure:: ../_images/metis_files_rxes.png
   :target: ../_images/metis_files_rxes.png
   :align: center

   :demeter:`metis`'s files tool in RXES mode.

In this case, a scan file is used to correlate image numbers with
energies.  There is a list of elastic files, but no separate list of
image files.

.. subfigstart::

.. figure:: ../_images/pt_rxes_1.png
   :target: ../_images/pt_rxes_1.png
   :align: center

   A Pt RXES image at a low energy.  This looks much like a normal
   elastic image.

.. figure:: ../_images/pt_rxes_2.png
   :target: ../_images/pt_rxes_2.png
   :align: center

   A Pt RXES image in the middle of the image sequence.  Here the
   fluorescence and the elastic line are quite close in energy.  The
   processing must somehow distinguish between the elastic and
   fluorescence portions of the signal.

.. figure:: ../_images/pt_rxes_3.png
   :target: ../_images/pt_rxes_3.png
   :align: center

   A Pt RXES image at the end of the image sequence.  Here the elastic
   signal is again easily distinguished form the fluorescence signal.
   The mask processing chore is to reject the fluorescence portion and
   retain the elastic portion.
   

.. subfigend::
   :width: 0.3
   :label: _fig-ptrxes

