..
   The Xray::BLA and Metis document is copyright 2016 Bruce Ravel and
   released under The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Tasks of the bla program
========================

Main tasks
----------


The :program:`bla` program is a simple multiplexer which parses the
command line arguments and performs the steps necessary to accomplish
the task.  The basic syntax is

.. code-block:: console

   bla <task> [switches] <stub>

where the first argument is one of the tasks below and the second
argument is the bit of text used to make file names for the
measurement.

**herfd**

   The ``herfd`` task makes a high energy resolution fluorescence
   spectrum at a specified emission energy.

   .. code-block:: console

      bla herfd -c=/path/to/config.ini -e=9713 Aufoil1

   Allowed switches are

   ``-e``
      (*required*) specify the emission energy for the HERFD
      calculation
   ``-r``
      Flag to reuse already computed masks which have been saved to disk
   ``-v``
      Control whether screen messages are written
   ``-s``
      Flag for saving mask images
   ``-a``
      Flag for saving animations (*not currently working*)
   ``-p``
      Flag to plot the HERFD upon completion
   ``-x``
      Specify the file containing XDI metadata

**rixs**

   The ``rixs`` task computes the HERFD at each elastic energy,
   writing an output file for each one.  This uses the list of
   emission energies specified in the configuration file.

   .. code-block:: console

      bla rixs -c=/path/to/config.ini Aufoil1

   Allowed switches are

   ``-r``
      Flag to reuse already computed masks which have been saved to disk
   ``-v``
      Control whether screen messages are written
   ``-s``
      Flag for saving mask images
   ``-a``
      Flag for saving animations (*not currently working*)
   ``-p``
      Flag to plot each HERFD as it is computed
   ``-x``
      Specify the file containing XDI metadata

**xes**

   The ``xes`` task computes the XES spectrum from an image at a
   specified incident energy.  The incidence energy is specified
   either with the ``-i`` or ``--xesimage`` switch, one of which must
   be used.  This will compute all the masks as needed.

   .. code-block:: console

      bla xes -c=/path/to/config.ini -i 11970 Aufoil1
      bla xes -c=/path/to/config.ini --noscan --xesimage=1  Nb2O3_Kb2_2

   Allowed switches are

   ``-i``
      (*required*) The incidence energy at which to compute the XES.  This form is used with a
      HERFD measurement to compute the XES at a particular incidence energy.
   ``--xesimage``
      (*required*) The index or file name of the XES image
   ``--noscan``
      Flag indicating the no scan file was used
   ``-r``
      Flag to reuse already computed masks which have been saved to disk
   ``-v``
      Control whether screen messages are written
   ``-s``
      Flag for saving mask images
   ``-a``
      Flag for saving animations (*not currently working*)
   ``-p``
      Flag to plot the XES upon completion
   ``-x``
      Specify the file containing XDI metadata

**plane**

   The ``plane`` task computes an entire RIXS plane, packaging the
   result for plotting as a surface plot.  This 

   .. code-block:: console

      bla plane -c=/path/to/config.ini Nb2O3_Kb2_2

   Allowed switches are

   ``--noscan``
      Flag indicating the no scan file was used
   ``-r``
      Flag to reuse already computed masks which have been saved to disk
   ``-v``
      Control whether screen messages are written
   ``-s``
      Flag for saving mask images
   ``-a``
      Flag for saving animations (*not currently working*)
   ``-p``
      Flag to plot the XES upon completion
   ``-x``
      Specify the file containing XDI metadata

**map**

  The ``map`` task takes a sequence of masks and interpolates them
  into a smooth map that can be used to make a surface plot of the
  energy distribution over the face of the detector.  The map can also
  be used to create a new mask of a specified energy width.

  *This is not currently working*

**mask**

  The ``mask`` task is used to create a mask at a specified emission
  energy.  This could be incorporated into a scan program.  A mask can
  be computed for a given emission energy as the subsequent emission
  energy is measured.  This calculation is typically faster than an
  elastic image exposure, thus mask creation can be incorporated into
  a measurement in almost-real-time.

   .. code-block:: console

      bla mask -c=/path/to/config.ini -e=9713 Aufoil1

   Allowed switches are

   ``-e``
      (*required*) specify the emission energy for the HERFD
      calculation
   ``-v``
      Control whether screen messages are written
   ``-s``
      Flag for saving mask images
   ``-a``
      Flag for saving animations (*not currently working*)
   ``-p``
      Flag to plot the HERFD upon completion

**point**

  The ``point`` task applies a specified mask to an image.  This could
  be incorporated into a scan program.  While a data point is being
  measured in a HERFD scan, the HERFD from the previous energy point
  can be computed.  In this way, an almost-real-time plot can be
  presented to the user of the HERFD being measured.

   .. code-block:: console

      bla mask -c=/path/to/config.ini -e=9713 Aufoil1

   Allowed switches are

   ``-e``
      (*required*) specify the emission energy for the HERFD
      calculation
   ``-i``
      (*required*) the incident energy or incident data point index to compute


Developer tasks
---------------

**list**

  This task lists all the attributes of the `Xray::BLA object
  <../lib/Xray/BLA.html>`_ along with a short documentation string.

**test**

  This task is used for testing new algorithms.
