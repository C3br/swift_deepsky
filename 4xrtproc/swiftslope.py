#!/usr/bin/env python
#-*- coding:utf8 -*-

# The hardness matrix
# -------------------
# It a file from Paolo's 'countrates' that contains a matrix of
#  expected hardness ratio for a given instrument, at different
#  Hydrogen column (NH) values, at different energies.
#
# The file has the following structure:
# First line: (20) values of NH, sort in incresing order
# Lines 2-41: Energy value followed by (20) hardness ratio
#
# The Hardness matrix for Swift, from 0.3-10keV is hardcoded at the
# end of this module: HARDNESS_MATRIX


def swift_hardconvert(hardness, nh, hardness_matrix=None):
    if nh is None:
        alpha = None
        return alpha

    if hardness_matrix != None:
        with open(hardness_matrix, 'r') as fp:
            hardness_matrix = [ line for line in fp.readlines() ]
    else:
        hardness_matrix = HARDNESS_MATRIX.split('\n')

    nhvalues = None
    energies = []
    hs_ratio = []
    for line in hardness_matrix:
        if nhvalues is None:
            # First line is the list of NH values; 20 values are expected
            nhvalues = [ float(v) for v in line.split() ]
            assert len(nhvalues) == 20
            continue
        vals = [ float(v) for v in line.split() ]
        if not vals: continue
        energies.append(vals[0])
        hs_ratio.append(vals[1:])
    assert len(hs_ratio[-1]) == len(nhvalues)

    import numpy
    nhvalues = numpy.array(nhvalues, dtype=float)
    energies = numpy.array(energies, dtype=float)
    hs_ratio = numpy.array(hs_ratio, dtype=float)
    assert nhvalues.ndim+energies.ndim == hs_ratio.ndim
    assert hs_ratio.shape == tuple([len(energies),len(nhvalues)])

    try:
        col = numpy.where(nh >= nhvalues)[0][-1]
    except:
        col = len(nhvalues)-1

    hs_good = hs_ratio[:,col] - hs_ratio[:,col-1]
    hs_good /= (nhvalues[col] - nhvalues[col-1])
    hs_good *= (nh - nhvalues[col-1])
    hs_good += hs_ratio[:,col-1]
    assert hs_good.ndim == 1
    assert hs_good.shape[0] == len(energies)

    hs_diff = numpy.abs(hardness - hs_good)
    i_good = numpy.where(hs_diff == hs_diff.min())[0]
    if len(i_good):
        assert len(i_good) == 1
        alpha = energies[i_good]
        if hardness > hs_good[i_good]:  # and i_good < len(energies)-1:
            try:
                alpha = energies[i_good+1] - energies[i_good]
                alpha *= (hardness - hs_good[i_good])
                alpha /= (hs_good[i_good+1] - hs_good[i_good])
                alpha += energies[i_good]
            except IndexError as e:
                alpha = energies[i_good] - energies[i_good-1]
                alpha /= (hs_good[i_good] - hs_good[i_good-1])
                alpha *= (hardness - hs_good[i_good-1])
                alpha += energies[i_good-1]
            except:
                alpha = [-99]
        else:
            alpha = energies[i_good] - energies[i_good-1]
            alpha /= (hs_good[i_good] - hs_good[i_good-1])
            alpha *= (hardness - hs_good[i_good-1])
            alpha += energies[i_good-1]
    else:
        alpha = [-99]

    assert len(alpha)==1
    return alpha[0]

def swiftslope(nh,countrate_hard,countrate_soft,hard_error=None,soft_error=None,hardness_matrix=None):
    import math
    if countrate_soft != 0:
        hardness = countrate_hard/countrate_soft
        if hard_error is None:
            hard_error = 0
        if soft_error is None:
            soft_error = 0
        hard_error = math.sqrt(hard_error**2 + hardness**2 * soft_error**2)
        hard_error /= countrate_soft

        hardness_plus = hardness+hard_error
        hardness_minus = hardness-hard_error
        alpha = swift_hardconvert(hardness,nh,hardness_matrix)
        alpha_minus = swift_hardconvert(hardness_plus,nh,hardness_matrix)
        alpha_plus = swift_hardconvert(hardness_minus,nh,hardness_matrix)
        aerrplus = alpha_plus - alpha
        aerrminus = alpha - alpha_minus
    else:
        alpha = -99
        aerrplus = -99
        aerrminus = -99
    return alpha,aerrplus,aerrminus

HARDNESS_MATRIX='''2.985E+19 4.454E+19 6.647E+19 9.919E+19 1.480E+20 2.209E+20 3.296E+20 4.919E+20 7.341E+20 1.095E+21 1.635E+21 2.440E+21 3.640E+21 5.433E+21 8.107E+21 1.210E+22 1.805E+22 2.694E+22 4.021E+22 6.000E+22
-1.0 3.713E+00 3.725E+00 3.742E+00 3.768E+00 3.806E+00 3.861E+00 3.944E+00 4.064E+00 4.238E+00 4.492E+00 4.861E+00 5.401E+00 6.207E+00 7.447E+00 9.447E+00 1.290E+01 1.944E+01 3.360E+01 7.032E+01 1.949E+02
-0.9 3.261E+00 3.272E+00 3.288E+00 3.311E+00 3.346E+00 3.397E+00 3.473E+00 3.583E+00 3.743E+00 3.975E+00 4.312E+00 4.804E+00 5.537E+00 6.663E+00 8.476E+00 1.160E+01 1.752E+01 3.031E+01 6.351E+01 1.755E+02
-0.8 2.864E+00 2.874E+00 2.888E+00 2.910E+00 2.942E+00 2.989E+00 3.059E+00 3.160E+00 3.307E+00 3.520E+00 3.828E+00 4.277E+00 4.945E+00 5.967E+00 7.613E+00 1.045E+01 1.581E+01 2.738E+01 5.732E+01 1.591E+02
-0.7 2.515E+00 2.524E+00 2.537E+00 2.557E+00 2.587E+00 2.630E+00 2.694E+00 2.787E+00 2.922E+00 3.117E+00 3.399E+00 3.810E+00 4.419E+00 5.350E+00 6.845E+00 9.415E+00 1.427E+01 2.476E+01 5.189E+01 1.436E+02
-0.6 2.207E+00 2.216E+00 2.228E+00 2.247E+00 2.274E+00 2.314E+00 2.373E+00 2.458E+00 2.582E+00 2.762E+00 3.020E+00 3.396E+00 3.951E+00 4.800E+00 6.160E+00 8.496E+00 1.290E+01 2.241E+01 4.692E+01 1.297E+02
-0.5 1.937E+00 1.945E+00 1.956E+00 1.973E+00 1.999E+00 2.036E+00 2.090E+00 2.169E+00 2.283E+00 2.448E+00 2.685E+00 3.029E+00 3.537E+00 4.311E+00 5.549E+00 7.674E+00 1.169E+01 2.030E+01 4.259E+01 1.173E+02
-0.4 1.700E+00 1.707E+00 1.717E+00 1.733E+00 1.756E+00 1.790E+00 1.840E+00 1.913E+00 2.018E+00 2.170E+00 2.388E+00 2.703E+00 3.168E+00 3.875E+00 5.006E+00 6.940E+00 1.059E+01 1.842E+01 3.860E+01 1.062E+02
-0.3 1.490E+00 1.497E+00 1.507E+00 1.521E+00 1.543E+00 1.574E+00 1.620E+00 1.688E+00 1.785E+00 1.924E+00 2.124E+00 2.414E+00 2.840E+00 3.487E+00 4.519E+00 6.285E+00 9.603E+00 1.674E+01 3.512E+01 9.622E+01
-0.2 1.306E+00 1.313E+00 1.322E+00 1.335E+00 1.355E+00 1.384E+00 1.426E+00 1.488E+00 1.578E+00 1.706E+00 1.891E+00 2.157E+00 2.548E+00 3.140E+00 4.084E+00 5.696E+00 8.723E+00 1.521E+01 3.191E+01 8.804E+01
-0.1 1.144E+00 1.150E+00 1.158E+00 1.171E+00 1.189E+00 1.216E+00 1.255E+00 1.312E+00 1.395E+00 1.514E+00 1.683E+00 1.928E+00 2.288E+00 2.831E+00 3.695E+00 5.168E+00 7.933E+00 1.386E+01 2.903E+01 7.997E+01
 0.0 1.002E+00 1.007E+00 1.015E+00 1.026E+00 1.043E+00 1.068E+00 1.104E+00 1.157E+00 1.233E+00 1.343E+00 1.499E+00 1.725E+00 2.055E+00 2.554E+00 3.346E+00 4.695E+00 7.224E+00 1.262E+01 2.643E+01 7.271E+01
 0.1 8.765E-01 8.813E-01 8.884E-01 8.989E-01 9.145E-01 9.374E-01 9.709E-01 1.020E+00 1.090E+00 1.191E+00 1.335E+00 1.543E+00 1.848E+00 2.306E+00 3.033E+00 4.269E+00 6.585E+00 1.153E+01 2.417E+01 6.618E+01
 0.2 7.662E-01 7.706E-01 7.771E-01 7.868E-01 8.012E-01 8.223E-01 8.532E-01 8.983E-01 9.633E-01 1.056E+00 1.190E+00 1.382E+00 1.662E+00 2.084E+00 2.752E+00 3.887E+00 6.006E+00 1.052E+01 2.206E+01 6.030E+01
 0.3 6.692E-01 6.733E-01 6.793E-01 6.882E-01 7.014E-01 7.209E-01 7.494E-01 7.910E-01 8.509E-01 9.370E-01 1.060E+00 1.237E+00 1.496E+00 1.885E+00 2.499E+00 3.541E+00 5.488E+00 9.634E+00 2.016E+01 5.499E+01
 0.4 5.839E-01 5.877E-01 5.932E-01 6.014E-01 6.136E-01 6.315E-01 6.578E-01 6.961E-01 7.515E-01 8.310E-01 9.449E-01 1.109E+00 1.347E+00 1.706E+00 2.272E+00 3.230E+00 5.017E+00 8.817E+00 1.844E+01 5.021E+01
 0.5 5.090E-01 5.124E-01 5.175E-01 5.251E-01 5.362E-01 5.527E-01 5.769E-01 6.122E-01 6.634E-01 7.368E-01 8.421E-01 9.936E-01 1.214E+00 1.545E+00 2.067E+00 2.950E+00 4.595E+00 8.078E+00 1.696E+01 4.589E+01
 0.6 4.432E-01 4.464E-01 4.510E-01 4.579E-01 4.682E-01 4.833E-01 5.056E-01 5.381E-01 5.853E-01 6.531E-01 7.504E-01 8.906E-01 1.095E+00 1.401E+00 1.883E+00 2.696E+00 4.213E+00 7.422E+00 1.555E+01 4.198E+01
 0.7 3.855E-01 3.884E-01 3.926E-01 3.990E-01 4.084E-01 4.223E-01 4.427E-01 4.726E-01 5.161E-01 5.787E-01 6.687E-01 7.985E-01 9.875E-01 1.271E+00 1.716E+00 2.468E+00 3.864E+00 6.816E+00 1.428E+01 3.845E+01
 0.8 3.349E-01 3.375E-01 3.414E-01 3.472E-01 3.558E-01 3.685E-01 3.873E-01 4.148E-01 4.548E-01 5.126E-01 5.958E-01 7.159E-01 8.912E-01 1.154E+00 1.566E+00 2.261E+00 3.548E+00 6.266E+00 1.312E+01 3.581E+01
 0.9 2.906E-01 2.930E-01 2.965E-01 3.018E-01 3.097E-01 3.213E-01 3.385E-01 3.637E-01 4.005E-01 4.538E-01 5.308E-01 6.420E-01 8.046E-01 1.048E+00 1.430E+00 2.072E+00 3.264E+00 5.779E+00 1.207E+01 3.289E+01
 1.0 2.518E-01 2.540E-01 2.572E-01 2.620E-01 2.692E-01 2.798E-01 2.955E-01 3.186E-01 3.524E-01 4.016E-01 4.727E-01 5.757E-01 7.266E-01 9.524E-01 1.306E+00 1.902E+00 3.003E+00 5.325E+00 1.112E+01 3.024E+01
 1.1 2.179E-01 2.199E-01 2.228E-01 2.272E-01 2.337E-01 2.434E-01 2.577E-01 2.789E-01 3.099E-01 3.551E-01 4.208E-01 5.163E-01 6.563E-01 8.661E-01 1.195E+00 1.747E+00 2.769E+00 4.912E+00 1.031E+01 2.784E+01
 1.2 1.883E-01 1.901E-01 1.928E-01 1.967E-01 2.026E-01 2.114E-01 2.245E-01 2.438E-01 2.722E-01 3.138E-01 3.745E-01 4.629E-01 5.930E-01 7.879E-01 1.093E+00 1.607E+00 2.553E+00 4.535E+00 9.516E+00 2.565E+01
 1.3 1.625E-01 1.641E-01 1.665E-01 1.701E-01 1.755E-01 1.834E-01 1.953E-01 2.129E-01 2.389E-01 2.771E-01 3.331E-01 4.151E-01 5.358E-01 7.173E-01 1.001E+00 1.478E+00 2.356E+00 4.203E+00 8.796E+00 2.366E+01
 1.4 1.401E-01 1.415E-01 1.437E-01 1.469E-01 1.517E-01 1.590E-01 1.697E-01 1.857E-01 2.095E-01 2.446E-01 2.962E-01 3.721E-01 4.843E-01 6.534E-01 9.176E-01 1.361E+00 2.177E+00 3.889E+00 8.138E+00 2.185E+01
 1.5 1.205E-01 1.218E-01 1.238E-01 1.267E-01 1.310E-01 1.375E-01 1.473E-01 1.618E-01 1.835E-01 2.156E-01 2.632E-01 3.334E-01 4.377E-01 5.951E-01 8.417E-01 1.255E+00 2.015E+00 3.603E+00 7.537E+00 2.020E+01
 1.6 1.036E-01 1.048E-01 1.065E-01 1.091E-01 1.130E-01 1.189E-01 1.277E-01 1.408E-01 1.605E-01 1.900E-01 2.337E-01 2.987E-01 3.957E-01 5.423E-01 7.722E-01 1.157E+00 1.865E+00 3.341E+00 6.988E+00 1.869E+01
 1.7 8.889E-02 8.993E-02 9.149E-02 9.383E-02 9.733E-02 1.026E-01 1.105E-01 1.224E-01 1.403E-01 1.672E-01 2.074E-01 2.675E-01 3.577E-01 4.945E-01 7.088E-01 1.068E+00 1.728E+00 3.101E+00 6.486E+00 1.732E+01
 1.8 7.618E-02 7.711E-02 7.850E-02 8.058E-02 8.371E-02 8.842E-02 9.553E-02 1.063E-01 1.225E-01 1.470E-01 1.839E-01 2.395E-01 3.233E-01 4.509E-01 6.513E-01 9.871E-01 1.602E+00 2.881E+00 6.026E+00 1.606E+01
 1.9 6.519E-02 6.602E-02 6.725E-02 6.911E-02 7.190E-02 7.610E-02 8.247E-02 9.213E-02 1.068E-01 1.291E-01 1.630E-01 2.143E-01 2.922E-01 4.113E-01 5.985E-01 9.123E-01 1.489E+00 2.688E+00 5.604E+00 1.490E+01
 2.0 5.571E-02 5.645E-02 5.754E-02 5.919E-02 6.167E-02 6.542E-02 7.111E-02 7.978E-02 9.303E-02 1.133E-01 1.443E-01 1.916E-01 2.640E-01 3.752E-01 5.502E-01 8.437E-01 1.383E+00 2.502E+00 5.216E+00 1.385E+01
 2.1 4.755E-02 4.820E-02 4.916E-02 5.062E-02 5.282E-02 5.615E-02 6.123E-02 6.899E-02 8.092E-02 9.929E-02 1.276E-01 1.713E-01 2.385E-01 3.423E-01 5.063E-01 7.808E-01 1.285E+00 2.331E+00 4.907E+00 1.288E+01
 2.2 4.053E-02 4.110E-02 4.195E-02 4.324E-02 4.518E-02 4.814E-02 5.265E-02 5.959E-02 7.031E-02 8.694E-02 1.128E-01 1.530E-01 2.154E-01 3.123E-01 4.659E-01 7.237E-01 1.195E+00 2.174E+00 4.579E+00 1.199E+01
 2.3 3.450E-02 3.500E-02 3.575E-02 3.689E-02 3.860E-02 4.122E-02 4.522E-02 5.140E-02 6.101E-02 7.602E-02 9.957E-02 1.365E-01 1.944E-01 2.850E-01 4.288E-01 6.706E-01 1.113E+00 2.029E+00 4.276E+00 1.118E+01
 2.4 2.933E-02 2.977E-02 3.043E-02 3.143E-02 3.294E-02 3.524E-02 3.878E-02 4.428E-02 5.287E-02 6.641E-02 8.782E-02 1.218E-01 1.755E-01 2.600E-01 3.948E-01 6.216E-01 1.036E+00 1.895E+00 3.998E+00 1.042E+01
 2.5 2.491E-02 2.529E-02 2.587E-02 2.675E-02 2.807E-02 3.010E-02 3.322E-02 3.810E-02 4.577E-02 5.794E-02 7.738E-02 1.085E-01 1.583E-01 2.372E-01 3.638E-01 5.766E-01 9.680E-01 1.772E+00 3.740E+00 9.734E+00
 2.6 2.113E-02 2.147E-02 2.197E-02 2.273E-02 2.390E-02 2.567E-02 2.843E-02 3.274E-02 3.957E-02 5.050E-02 6.811E-02 9.662E-02 1.427E-01 2.164E-01 3.352E-01 5.350E-01 9.029E-01 1.658E+00 3.503E+00 9.097E+00
 2.7 1.790E-02 1.820E-02 1.864E-02 1.930E-02 2.032E-02 2.188E-02 2.429E-02 2.810E-02 3.417E-02 4.395E-02 5.989E-02 8.596E-02 1.286E-01 1.975E-01 3.088E-01 4.967E-01 8.427E-01 1.552E+00 3.283E+00 8.510E+00
 2.8 1.515E-02 1.541E-02 1.579E-02 1.637E-02 1.725E-02 1.862E-02 2.074E-02 2.409E-02 2.947E-02 3.821E-02 5.260E-02 7.641E-02 1.158E-01 1.801E-01 2.846E-01 4.619E-01 7.870E-01 1.454E+00 3.080E+00 7.968E+00
 2.9 1.281E-02 1.303E-02 1.337E-02 1.387E-02 1.464E-02 1.583E-02 1.768E-02 2.063E-02 2.539E-02 3.319E-02 4.615E-02 6.786E-02 1.042E-01 1.642E-01 2.623E-01 4.291E-01 7.354E-01 1.371E+00 2.891E+00 7.467E+00
 3.0 1.082E-02 1.102E-02 1.130E-02 1.174E-02 1.241E-02 1.344E-02 1.506E-02 1.765E-02 2.184E-02 2.879E-02 4.044E-02 6.021E-02 9.372E-02 1.496E-01 2.417E-01 3.989E-01 6.875E-01 1.286E+00 2.717E+00 7.004E+00
'''

def print_oneline(alpha,aerrplus,aerrminus):
    fmt = '{:.3f} +{:.2f} -{:.2f}'
    print(fmt.format(alpha,aerrplus,aerrminus))

def print_original(alpha,aerrplus,aerrminus):
    print ('                    -{:.2f}'.format(aerrminus))
    print (' energy index= {:.3f}'.format(alpha))
    print ('                    +{:.2f}'.format(aerrplus))

if __name__ == '__main__':
    import sys

    ONELINE=False

    if len(sys.argv) == 1:
        ct_soft,soft_error = [ float(v) for v in input('Enter countrate and error in 0.3-2.0 keV band: ').split() ]
        ct_hard,hard_error = [ float(v) for v in input('Enter countrate and error in 2.0-10.0 keV band: ').split() ]
        nh = float(input('Enter NH: '))
        # alpha,aerrplus,aerrminus = swiftslope(nh,ct_hard,ct_soft,hard_error,soft_error)
        # print ('                    -{:.2f}'.format(aerrminus))
        # print (' energy index= {:.3f}'.format(alpha))
        # print ('                    +{:.2f}'.format(aerrplus))
    else:
        import argparse
        parser = argparse.ArgumentParser(description='Compute spectrum energy index')
        parser.add_argument('--soft', type=float, help='Countrate in soft(0.3-2.0 keV) band')
        parser.add_argument('--soft_error', type=float, help='Countrate error in soft(0.3-2.0 keV) band')
        parser.add_argument('--hard', type=float, help='Countrate in hard(0.3-2.0 keV) band')
        parser.add_argument('--hard_error', type=float, help='Countrate error in hard(0.3-2.0 keV) band')
        parser.add_argument('--nh', type=float, help='Hydrogen column at the flux direction')
        parser.add_argument('--oneline', action='store_true', help='Output in one line ("slope slope_plus-error slope_minus-error")')

        args = parser.parse_args()
        ONELINE=args.oneline
        nh = args.nh
        ct_hard = args.hard
        ct_soft = args.soft
        hard_error = args.hard_error
        soft_error = args.soft_error

    alpha,aerrplus,aerrminus = swiftslope(nh,ct_hard,ct_soft,hard_error,soft_error)
    if ONELINE:
        print_oneline(alpha,aerrplus,aerrminus)
    else:
        print_original(alpha,aerrplus,aerrminus)
