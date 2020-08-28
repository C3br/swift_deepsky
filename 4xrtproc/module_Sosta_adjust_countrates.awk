#!/usr/bin/env awk

# This script adjust the measurements made by SOSTA; for each detected
# source it takes SOSTA's measurement ratios (e.g, soft/full, hard/full)
# and multiplies by the previously measured full-band value made by
# XImage's DETECT (which looks more reliable).
#
# The input file is like the example below:
#-----------------------------------------------------------------------
#
#            RA            DEC  photon_flux[cts/s]  photon_flux_error[cts/s]  \
#  01:26:57.165  +33:07:27.142            0.054112                    0.0041
#  01:27:30.469  +33:02:44.225            0.007569                    0.0017
#
# exptime[s]  photon_flux_0.3-10keV(ph.s-1)  \
#    3493.07                       0.058920
#    3632.94                       0.007067
#
# photon_flux_error_0.3-10keV(ph.s-1) upper_limit_0.3-10keV(ph.s-1)  \
#                              0.0053                          None
#                              0.0024                          None
#
# exposure_time_0.3-10keV(s)  expected_background_0.3-10keV(ph)  \
#                   3637.877                           0.249656
#                   3720.830                           0.123805
#
# detected_counts_0.3-10keV(ph)  photon_flux_0.3-1keV(ph.s-1)  \
#                         123.0                      0.025390
#                           9.0                      0.002356
#
# photon_flux_error_0.3-1keV(ph.s-1) upper_limit_0.3-1keV(ph.s-1)  \
#                             0.0035                         None
#                             0.0014                         None
#
# exposure_time_0.3-1keV(s)  expected_background_0.3-1keV(ph)  \
#                  3637.877                          0.106844
#                  3720.830                          0.052985
#
# detected_counts_0.3-1keV(ph)  photon_flux_1-2keV(ph.s-1)  \
#                         53.0                    0.021080
#                          3.0                    0.003141
#
# photon_flux_error_1-2keV(ph.s-1) upper_limit_1-2keV(ph.s-1)  \
#                           0.0032                       None
#                           0.0016                       None
#
# exposure_time_1-2keV(s)  expected_background_1-2keV(ph)  \
#                3637.877                        0.063819
#                3720.830                        0.031648
#
# detected_counts_1-2keV(ph)  photon_flux_2-10keV(ph.s-1)  \
#                       44.0                      0.01245
#                        4.0                      0.00157
#
# photon_flux_error_2-10keV(ph.s-1) upper_limit_2-10keV(ph.s-1)  \
#                            0.0024                        None
#                            0.0011                        None
#
# exposure_time_2-10keV(s)  expected_background_2-10keV(ph)  \
#                 3637.877                         0.086292
#                 3720.830                         0.042793
#
# detected_counts_2-10keV(ph)
#                        26.0
#                         2.0
#


BEGIN{
  printf "#RA;DEC";
  printf ";countrates_0.3-10keV(ph.s-1);countrates_error_0.3-10keV(ph.s-1)";
  printf ";exposure_time(s)";
  printf ";countrates_0.3-1keV(ph.s-1);countrates_error_0.3-1keV(ph.s-1);upper_limit_0.3-1keV(ph.s-1)";
  printf ";countrates_1-2keV(ph.s-1);countrates_error_1-2keV(ph.s-1);upper_limit_1-2keV(ph.s-1)";
  printf ";countrates_2-10keV(ph.s-1);countrates_error_2-10keV(ph.s-1);upper_limit_2-10keV(ph.s-1)";
  printf "\n";
}
{
  ra=$1;
  dec=$2;

  det_cts=$3;
  det_err=$4;
  exp_time=$5;

  cts_full=$6;
  err_full=$7;

  if(cts_full == "None" || err_full == "None"){ next }

  cts_soft=$11;
  err_soft=$12;
  ul_soft=$13;

  cts_medium=$16;
  err_medium=$17;
  ul_medium=$18;

  cts_hard=$21;
  err_hard=$22;
  ul_hard=$23;

  if(ul_soft == "None"){
    ul_soft = -999
    ratio_soft=cts_soft/cts_full;
    ratio_soft_err=err_soft/err_full;
  }else{
    ul_soft = det_cts*ul_soft/cts_full;
    ratio_soft_err = -999;
  }
  corr_soft=det_cts*ratio_soft;
  corr_soft_err=det_err*ratio_soft_err;

  if(ul_medium == "None"){
    ul_medium = -999
    ratio_medium=cts_medium/cts_full;
    ratio_medium_err=err_medium/err_full;
  }else{
    ul_medium = det_cts*ul_medium/cts_full;
    ratio_medium_err = -999;
  }
  corr_medium=det_cts*ratio_medium;
  corr_medium_err=det_err*ratio_medium_err;

  if(ul_hard == "None"){
    ul_hard = -999
    ratio_hard=cts_hard/cts_full;
    ratio_hard_err=err_hard/err_full;
  }else{
    ul_hard = det_cts*ul_hard/cts_full;
    ratio_hard_err = -999;
  }
  corr_hard=det_cts*ratio_hard;
  corr_hard_err=det_err*ratio_hard_err;

  printf "%s;%s",ra,dec;
  printf ";%.3E;%.3E",det_cts,det_err;
  printf ";%.1f",exp_time;
  printf ";%.3E;%.3E;%.3E",corr_soft,corr_soft_err,ul_soft;
  printf ";%.3E;%.3E;%.3E",corr_medium,corr_medium_err,ul_medium;
  printf ";%.3E;%.3E;%.3E",corr_hard,corr_hard_err,ul_hard;
  printf "\n";
}
