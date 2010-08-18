package ParseSrt;

use strict;
use warnings;

sub str2ms {
  my $str = shift;

  my($h, $m, $s, $ms) = $str =~ /^(\d+):(\d+):(\d+),(\d{1,3})$/
  or die "Wrong time: $str";

  $ms .= '0' x (3 - length($ms)); # zero pad

  return $h * 3600000 + $m * 60000 + $s * 1000 + $ms;
}

sub ms2str {
  my $tm = shift;

  my $ms = $tm % 1000;
  $tm = int($tm / 1000);
  my $s = $tm % 60;
  $tm = int($tm / 60);
  my $m = $tm % 60;
  my $h = int($tm / 60);

  return sprintf("%02d:%02d:%02d,%03d", $h, $m, $s, $ms);
}

sub read_subs {
  my $file = shift;
  my $enc = shift;

  my @subs;
  my $nextline = 'id';
  my($id, $item);
  open(my $hf, "<:encoding($enc)", $file) or die $!;
  my $getline = sub { 
    if(defined(my $s = <$hf>)) {
      chomp($s);
      $s =~ s/^\s+//; $s =~ s/\s+$//;
      $s =~ s/^\x{FEFF}//; # skip BOM
      return $s;
    }
    return;
  };

  while(defined(my $s = $getline->())) {
    next unless $s;

    my $id = $s;
    die "Wrong ID: $s" unless $id =~ /^\d+$/;
    $s = $getline->();
    my($tm1, $tm2) = split / --> /, $s;
    my $start = str2ms($tm1);
    my $stop = str2ms($tm2);
    my $dur = $stop - $start;
    die "Wrong duration for $tm1, $tm2" if $dur < 0;
    my @text;
    while(my $s = $getline->()) {
      push(@text, $s);
    }
    die "Empty subtitles text for ID=$id" unless @text;
    push(@subs, {
	ID => $id,
	START => $start,
	DUR => $dur,
	TEXT => \@text,
    });
  }
  close($hf);

  return \@subs
}

1;
