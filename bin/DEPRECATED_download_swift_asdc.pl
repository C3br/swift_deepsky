#!/usr/bin/env perl

# This script downloads Swift/XRT data from ASDC,
# the ASI Science Data Center, by simulatig user
# interaction and subsequently downloading the
# selected data.
# The data selection is done at a given observation
# page at 'https://swift.ssdc.asi.it/cgi-bin/listobs?seq=<SEQ>&date=<DATE>',
# where <SEQ> and <DATE> refer to the observation.
#
# The script is run as:
# ```
# ./download_swift_asdc.pl ${OBSID} ${DATE} ${TARBALL} ${DESTDIR}
# ```
# Where `DESTDIR` is where to put the downloaded data,
# `TARBALL` is the name of the output data package,
# `DATE` is in the format `YYYY_MM`,
# `OBSID` is -- `seq` -- the observation ID.
#

use strict;
use warnings;
use Carp::Assert;

use feature qw(say);

# Script to download Swift data from ASDC (http://swift.asdc.asi.it)
# ASDC's interface to Swift data archive is a web form, this script
# interacts with that form, for a given Observation-ID and download
# the corresponding data package (which is a tarball).
#
# The following command-line should download observation
# ./download_swift_asdc.pl 00087081007 2017_08 /tmp/00087081007.tar ./

# Function to retrieve all GRBs table detected by Swift only
use WWW::Mechanize;
sub open_url {
  my $seq = $_[0];
  my $date = $_[1];
  my $baseurl = 'http://swift.asdc.asi.it/cgi-bin/listobs';
  my $url = sprintf('%s?seq=%011d&date=%s',$baseurl,$seq,$date);
  use WWW::Mechanize;
  my $mech = WWW::Mechanize->new();
  $mech->get( $url );
  return $mech;
}

# The ASI interface allows we to download sub-folders or individual
# files from an observation. The following variable, if set to '1',
# will make the algorithm to download all files from an observation.
my $ALL_FILES=0;

sub download_observation {
  # Arguments
  # - OBSID (11 digits)
  # - DATE (YYYY_MM)
  # - OUTDIR
  my $seq = $_[0];
  my $date = $_[1];
  my $tarfile = $_[2];

  my $mech = open_url($seq,$date);
  my $form = $mech->form_number(1);

  $mech->set_visible( [ radio => "tar" ] );
  if ($ALL_FILES==1) {
    $mech->tick("/","on");
  } else {
    # $mech->tick("/xrt/event","on");
    # $mech->tick("/xrt/products","on");
    $mech->tick("/xrt","on");
  }
  $mech->submit();

  # my $tarfile = sprintf("%s/%011d.tar",$tmpdir,$seq);
  $mech->save_content($tarfile);
  # return $tarfile;
}

sub unpack_observation {
  # Arguments
  # - TAR-FILE
  # - OUTDIR
  my $tarfile = $_[0];
  my $extract_dir = $_[1];

  use Archive::Tar;
  my $tar = Archive::Tar->new($tarfile);
  # $tar->extract();
  my @files = $tar->list_files;
  foreach my $file (@files)
  {
    my $extfile = sprintf("%s/%s",$extract_dir,$file);
    $tar->extract_file($file, $extfile);
  }
}

sub system_unpack_observation {
  my $tarfile = $_[0];
  my $outdir = $_[1];

  my @tarcmd = ("tar", "-xf", $tarfile, "--directory", $outdir);
  system(@tarcmd);
  unlink $tarfile;
}



my $nargs = $#ARGV + 1;
if ($nargs < 3) {
  say "\nUsage: $0 <OBSID> <START_TIME> <output.tar> [dest-dir]";
  say "";
  say "Positional arguments:";
  say "  OBSID      : Swift 11-digits observation identifier";
  say "  START_TIME : observation's date in format 'YYYY_MM'";
  say "  output.tar : output filename, it is a tarball;";
  say "               a fullpath may be given, for example, to a TMPDIR.";
  say "  dest-dir   : (optional) directory to write extracted data;";
  say "               if defined, is where the tarball will be extracted to.";
  say "";
  exit 1;
}

my $obsid = $ARGV[0];
my $date = $ARGV[1];
my $tarfile = $ARGV[2];

# my $tmpdir = "./";
# if ($nargs >= 3) {
#   $tmpdir = $ARGV[2];
# }
# if (not(-e $tmpdir and -d $tmpdir and -w $tmpdir)) {
#   say "\nERROR: Verify '$tmpdir', it be a directory and writable by you\n";
#   exit 1;
# }

my $outdir;
if ($nargs >= 4) {
  $outdir = $ARGV[3];
  if (not(-e $outdir and -d $outdir and -w $outdir)) {
    say "\nERROR: Verify '$outdir', it has to be a directory and writable by you\n";
    exit 1;
  }
}

# my $obsdir = sprintf("%s/%011d",$outdir,$obsid);
# if (-e $obsdir) {
#   say "\nObservation '$obsid' already in archive (under '$outdir')";
#   exit 0;
# }

say "# Downloading observation '$obsid'..";
# my $filename = download_observation($obsid,$date,$tmpdir);
download_observation($obsid,$date,$tarfile);

if (defined($outdir)){
  # unpack_observation($tarfile,$outdir)
  system_unpack_observation($tarfile,$outdir)
}
