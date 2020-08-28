#!/usr/bin/env python

# This simple-ugly-working script takes a file like the one below
# and transform in a table.
#
# Example input file
#------------------------------------------------------------------------------
#  read/size=800/ecol=PI/emin=30/emax=1000 22_33_15_sum.evt
#  Telescope SWIFT XRT
#  Image size = 800 x 800 pixels
#  Image rebin = 1.000
#  Image center = 500.5, 500.5
#  Energy column = PI Min = 30 Max = 1000
#  Using gti for exposure 3720.83320004 s
#  Reading an events file
#  File contains       1194 events
#  Accepted: 955 Rejected: 239
#   Image level, min = 0.0000000 max = 8.0000000
#  Copied MAP1 to MAP9
#  smooth/wave/sigma=5/back=1.0
#  Sigma (arcmin) :    0.19644
#  Calculating background: Poisson statistics assumed
#  Background box size =  64
#  Background =2.1887E-03 cts/original-pixel
#             =2.1887E-03 cts/image-pixel
#             =3.8109E-04 cts/sqarcmin/s
#             =5.8824E-07 cts/original-pixel/s
#   Scaling factor :    456.88196
#   Min and max :    0.0000000       638.00000
#  Max-preserving scaling factor :     5.7289274
# cpd 22_33_15_sum.smooth.band30-1000daeV.gif/gif
#  disp
#  Plotting image
#   Min =   0.0000000      Max =    638.00000
#  read/size=800/ecol=PI/emin=30/emax=1000 22_33_15_sum.evt
#  Telescope SWIFT XRT
#  Image size = 800 x 800 pixels
#  Image rebin = 1.000
#  Image center = 500.5, 500.5
#  Energy column = PI Min = 30 Max = 1000
#  Using gti for exposure 3720.83320004 s
#  Reading an events file
#  File contains       1194 events
#  Accepted: 955 Rejected: 239
#   Image level, min = 0.0000000 max = 8.0000000
#  read/size=800/expo .//22_33_15_sum.exp
#  Telescope SWIFT XRT
#  Image size = 800 x 800 pixels
#  Image rebin = 1.000
#  Image center = 500.5, 500.5
#  Reading an image
#   Image level, min = 0.0000000 max = 3698.0923
#  sosta/xpix=495.04999/ypix=584.84375/back=5.2715291E-07/eef_s=0.7
#  Using MAP1
#  Using constant background...
#                     X = 495.04999    Y = 584.84375
#   Using average energy for PSF:    1.0000000
#  Source half-box for 0.66 EEF is    5.8 pixels
#         Half-box for 0.90 EEF is   17.2 pixels
#  Total # of counts 122.00000 (in 121 elemental sq pixels)
#  Vignetting is part of exposure map
#  Background/elemental sq pixel :                5.272E-07 +/- 6.6E-05
#  Background/elemental sq pixel/sec :            1.464E-10 +/- 1.8E-08
#
#  Source counts :                                1.220E+02 +/- 1.1E+01
#  s.c. corrected for PSF + sampling dead time
#                                 + vignetting    2.080E+02 +/- 1.9E+01
#  Source intensity :                             3.388E-02 +/- 3.1E-03 c/sec
#  s.i. corrected for PSF + sampling dead time
#                                 + vignetting -> 5.776E-02 +/- 5.2E-03 c/sec <-
#  Signal to Noise Ratio             :            1.105E+01
#
#
#     Vignetting corrected exposure :       3601.206 s
#     Sampling dead time correction :      1.000
#     PSF correction                :      1.705
#     Optimum half box size is      : 74.500000 orig pixels
#  sosta/xpix=317.23529/ypix=464.47058/back=5.2715291E-07/eef_s=0.6
#  Using MAP1
#  Using constant background...
#                     X = 317.23529    Y = 464.47058
#   Using average energy for PSF:    1.0000000
#  Source half-box for 0.52 EEF is    3.8 pixels
#         Half-box for 0.90 EEF is   14.4 pixels
#  Total # of counts 10.000000 (in 64 elemental sq pixels)
#  Vignetting is part of exposure map
#  Background/elemental sq pixel :                5.272E-07 +/- 9.1E-05
#  Background/elemental sq pixel/sec :            1.579E-10 +/- 2.7E-08
#
#  Source counts :                                1.000E+01 +/- 3.2E+00
#  s.c. corrected for PSF + sampling dead time
#                                 + vignetting    2.619E+01 +/- 8.3E+00
#  Source intensity :                             2.996E-03 +/- 9.5E-04 c/sec
#  s.i. corrected for PSF + sampling dead time
#                                 + vignetting -> 7.846E-03 +/- 2.5E-03 c/sec <-
#  Signal to Noise Ratio             :            3.162E+00
#                                                  Poisson    Gauss
#  Pr. that source is a fluctuation of back. :    0.00E+00   0.00E+00
#
#
#     Vignetting corrected exposure :       3337.614 s
#     Sampling dead time correction :      1.000
#     PSF correction                :      2.619
#     Optimum half box size is      : 56.500000 orig pixels
# exit
#------------------------------------------------------------------------------

import sys

if len(sys.argv) < 3:
    from os.path import basename
    print('\nUsage: {} <sosta.log> <xray-band>'.format(basename(sys.argv[0])))
    sys.exit(1)

SOSTAFILE = sys.argv[1]
BAND = sys.argv[2]

fp = open(SOSTAFILE)
flux_neg = None
flux_pos = None
back = None
size = None
expo = None
ul = None
error = None
counts = None

SEP = ' '
print(SEP.join(['photon_flux_{0}(ph.s-1)',
                'photon_flux_error_{0}(ph.s-1)',
                'upper_limit_{0}(ph.s-1)',
                'expected_background_{0}(ph)',
                'detected_counts_{0}(ph)']).format(BAND))


def print_fluxes(flux, error, ul, expect, counts):
    fmt = "{1:.4E}{0}{2}{0}{3}{0}{4:E}{0}{5:.1f}"
    print(fmt.format(SEP, flux, error, ul, expect, counts))


for i, line in enumerate(fp.readlines()):

    if 'Background/elemental sq pixel :' in line:
        fields = line.split()
        back = fields[4]

    if 'Total # of counts' in line:
        fields = line.split()
        counts = float(fields[4])
        size = fields[6]

    if '+ vignetting ->' in line:
        fields = line.split()
        # Here we have to fix for a weak formating of the sosta.log,
        # if the reported flux is negative, because of the "-" the value
        # is reported attached to "->":
        # """
        # + vignetting ->-3.412E-09 +/- 7.3E-07 c/sec <-
        # """
        # Otherwise, if positive, it is reported "correctly":
        # """
        # + vignetting -> 6.235E-04 +/- 3.1E-04 c/sec <-
        # """
        if len(fields) == 8:
            flux_pos = fields[3]
            flux = float(flux_pos)
            error = fields[5]
        else:
            assert len(fields) == 7
            flux_neg = fields[2]
            flux_neg = flux_neg[2:]
            flux = float(flux_neg)
            error = fields[4]

    # if 'Exposure time' in line:
    #     fields = line.split()
    #     expo = fields[3]
    if 'Vignetting corrected exposure :' in line:
        fields = line.split()
        expo = fields[4]

    if 'upper' in line:
        fields = line.split()
        ul = fields[5]

    if 'sosta' in line:
        if back is None:
            continue

        if ul is not None:
            error = None

        expect = float(back) * int(size) * float(expo)

        print_fluxes(flux, error, ul, expect, counts)

        # Clear variables
        flux_neg = None
        flux_pos = None
        back = None
        size = None
        expo = None
        ul = None
        error = None
        counts = None

if ul is not None:
    error = None

expect = float(back) * int(size) * float(expo)

print_fluxes(flux, error, ul, expect, counts)
