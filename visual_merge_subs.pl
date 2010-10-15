#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Encode;
use lib "$FindBin::Bin";
use ParseSrt;
use Data::Dumper;

my($badfile, $goodfile, $vmergefile, $enc) = @ARGV;
unless($badfile && $goodfile && $vmergefile) {
  die "Usage: $0 bad-srt-file good-srt-file mergefile [encoding]\n";
}
$enc ||= "UCS-2LE";
my $CRLF = "\r\n";

my $badsubs = ParseSrt::read_subs($badfile, $enc);
my $goodsubs = ParseSrt::read_subs($goodfile, $enc);
#die Dumper($map, $subs); # FIXME

open(my $hdest, ">:raw", $vmergefile) or die $!;
print $hdest Encode::encode('utf-8', "\x{FEFF}");
print $hdest "<html><body><table>";
my $gi = 0;
foreach my $bi (0 .. $#$badsubs) {
	my $bsub = $badsubs->[$bi];
	if($bi < $#$badsubs) {
		if($bsub->{START} + $bsub->{DUR} >= $badsubs->[$bi + 1]->{START}) {
			$bsub->{OVERLAP} = 1;
			print "OVERLAP: $bsub->{ID}\n";
		}
	}
	
	while($goodsubs->[$gi]->{START} <= $bsub->{START} && $gi < $#$goodsubs) {
		$gi++;
	}
	
	my $best_gi = $gi;
	my $diff = abs($goodsubs->[$gi]->{START} - $bsub->{START});
	if($gi > 0) {
		my $diff_pre = abs($goodsubs->[$gi - 1]->{START} - $bsub->{START});
		if($diff_pre < $diff) {
			$best_gi = $gi - 1;
			$diff = $diff_pre;
		}
	}

	if($diff <= 800) {
		# previous pair
		if(my $prev_bi = $goodsubs->[$best_gi]->{PAIR}) {
			if($goodsubs->[$best_gi]->{DIFF} > $diff) {
#				printf "unlink %d,%s\n", $prev_bi, $best_gi; # FIXME
				delete $badsubs->[$prev_bi]->{PAIR};
				$bsub->{PAIR} = $best_gi;
				$goodsubs->[$best_gi]->{PAIR} = $bi;
				$goodsubs->[$best_gi]->{DIFF} = $diff;
			}
		} else {
			$bsub->{PAIR} = $best_gi;
			$goodsubs->[$best_gi]->{PAIR} = $bi;
			$goodsubs->[$best_gi]->{DIFF} = $diff;
		}
#		printf "%d,%d: %d\n", $bi, $best_gi, $diff; # FIXME
	}


#  print $hdest Encode::encode($enc, "$id$CRLF");
#  print $hdest Encode::encode($enc, "$tm1 --> $tm2$CRLF");
#  print $hdest Encode::encode($enc, "$_$CRLF") foreach @{$sub->{TEXT}};
#  print $hdest Encode::encode($enc, $CRLF);
}

#print Dumper($badsubs, $goodsubs); exit 1; # FIXME

{
	while(@$goodsubs || @$badsubs) {
		my $bsub = shift @$badsubs;
		my $gsub = shift @$goodsubs;
		if($bsub && exists $bsub->{PAIR}) {
			while(! exists $gsub->{PAIR}) {
				prsubs($hdest, undef, $gsub);
				$gsub = shift @$goodsubs;
			}
		} elsif($gsub && exists $gsub->{PAIR}) {
			while(! exists $bsub->{PAIR}) {
				prsubs($hdest, $bsub, undef);
				$bsub = shift @$badsubs;
			}
		}
		prsubs($hdest, $bsub, $gsub);
	}
	
}

print $hdest "</table></body></html>";
close($hdest);

exit 0;

sub sub2html {
	my $sub = shift;

	my $style = $sub->{OVERLAP} ? 'color: red; font-weight: bold' : 'color: black;';
	my $s = $sub->{ID}  . "<br>";
	$s .= "<span style='$style'>" . ParseSrt::ms2str($sub->{START}) . "&nbsp;" . ParseSrt::ms2str($sub->{START}+$sub->{DUR}) . "</span><br>";
	$s .= "$_<br>" foreach @{$sub->{TEXT}};
	return $s;
}

sub prsubs {
	my $hdest = shift;
	my $sub1 = shift;
	my $sub2 = shift;

	my $ssub1 = $sub1 ? sub2html($sub1) : '';
	my $ssub2 = $sub2 ? sub2html($sub2) : '';
	my $diff = '';
	my $style = 'color: black;';
	my $pair = '';
	if($sub1 && exists $sub1->{PAIR}) {
		$pair = " $sub1->{ID}  $sub2->{ID}";
		$diff = $sub1->{START} - $sub2->{START};
		if(abs($diff) >= 300) {
			$style = 'color: red; font-weight: bold';
		} elsif(abs($diff) >= 200) {
			$style = 'color: red;';
		}
	}
	print $hdest Encode::encode('utf-8', "<tr><td>$ssub1</td><td>$ssub2</td><td style='$style'>$diff</td><td>$pair</td><tr>\n");
}
