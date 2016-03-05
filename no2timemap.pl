#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Encoding;
use lib "$FindBin::Bin";
use ParseSrt;
use Data::Dumper;

my($srcmapfile, $badfile, $goodfile, $destmapfile, $enc) = @ARGV;
unless($srcmapfile && $badfile && $goodfile && $destmapfile) {
  die "Usage: $0 src-map bad-srt-file good-srt-file dest-map [encoding]\n";
}
$enc ||= "UCS-2LE";
my $CRLF = "\r\n";

my $badsubs = ParseSrt::read_subs($badfile, $enc);
my $goodsubs = ParseSrt::read_subs($goodfile, $enc);
my %bad_times = map { $_->{ID} => $_->{START} } @$badsubs;
my %good_times = map { $_->{ID} => $_->{START} } @$goodsubs;
my $map = read_no_map($srcmapfile);
#die Dumper($map, $subs); # FIXME

open(my $hdest, '>', $destmapfile) or die $!;
foreach my $badno (keys %$map) {
  my $isno = $badno =~ /^\d+$/;
  my $goodno = $map->{$badno};

  my $bad_time = ($isno ? ParseSrt::ms2str($bad_times{$badno}) : $badno)
  or die "No time for bad no=$badno\n";
  my $good_time = ($isno ? ParseSrt::ms2str($good_times{$goodno}) : $goodno)
  or die "No time for good no=$goodno\n";

  printf $hdest ("%s\t%s\n", $bad_time, $good_time);
}
close($hdest);

exit 0;

sub read_no_map {
  my $file = shift;
  
  my %map;
  open(my $hmap, $file) or die "open($file): $!";
  while(my $s = <$hmap>) {
	next if $s =~ /^#/;
    my($from, $to) = split /\s+/, $s;
    next unless $from;
    if(exists $map{$from} && $map{$from} != $to) {
      die "Duplicate map item: $from\n";
    }
	$map{$from} = $to;
  }
  close($hmap);
 
  return \%map;
}

