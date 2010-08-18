use strict;
use warnings;
use FindBin;
use Encoding;
use lib "$FindBin::Bin";
use ParseSrt;
use Data::Dumper;

my($mapfile, $srcfile, $enc) = @ARGV;
unless($mapfile && $srcfile) {
  die "Usage: $0 map srt-file [encoding]\n";
}
$enc ||= "UCS-2LE";
my $CRLF = "\r\n";

my $subs = ParseSrt::read_subs($srcfile, $enc);
my $map = read_map($mapfile);
my $destfile = "fix.".$srcfile;
#die Dumper($map, $subs); # FIXME

open(my $hdest, ">:raw", $destfile) or die $!;
if($enc =~ /ucs|utf/i) {
  print $hdest Encode::encode($enc, "\x{FEFF}");
}
my $id = 1;
foreach my $sub (@$subs) {
  my $start = $sub->{START};
  my $ok = 0;
  foreach my $im (0 .. $#$map) {
    $ok = 1;
    my $m = $map->[$im];
    if($start == $m->[0]) {
      $start = $m->[1];
      last;
    }
    elsif($start < $m->[0]) {
      my($f2, $t2) = @$m;
      if($im == 0) {
	die "No lower bound for time=$start (id=$sub->{ID})\n";
      }
      my($f1, $t1) = @{$map->[$im - 1]};
      $start = ($start - $f1) / ($f2 - $f1) * ($t2 - $t1) + $t1;
      last;
    }
    $ok = 0;
  }
  unless($ok) {
    die "No upper bound for time=$start (id=$sub->{ID})\n";
  }
  my $tm1 = ParseSrt::ms2str($start);
  my $tm2 = ParseSrt::ms2str($start + $sub->{DUR});

  print $hdest Encode::encode($enc, "$id$CRLF");
  print $hdest Encode::encode($enc, "$tm1 --> $tm2$CRLF");
  print $hdest Encode::encode($enc, "$_$CRLF") foreach @{$sub->{TEXT}};
  print $hdest Encode::encode($enc, $CRLF);

  $id++;
}

exit 0;

sub read_map {
  my $file = shift;
  
  my @map;
  my %from_exists;
  open(my $hmap, $file) or die "open($file): $!";
  while(my $s = <$hmap>) {
    my($from, $to) = split /\s+/, $s;
    next unless $from;
    if(exists $from_exists{$from}) {
      die "Duplicate time: $from\n";
    }
    push(@map, [ParseSrt::str2ms($from), ParseSrt::str2ms($to)]);
  }
  close($hmap);
 
  @map = sort { $a->[0] <=> $b->[0] } @map;

  return \@map;
}

