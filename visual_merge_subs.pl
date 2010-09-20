use strict;
use warnings;
use FindBin;
use Encoding;
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
	}

#  print $hdest Encode::encode($enc, "$id$CRLF");
#  print $hdest Encode::encode($enc, "$tm1 --> $tm2$CRLF");
#  print $hdest Encode::encode($enc, "$_$CRLF") foreach @{$sub->{TEXT}};
#  print $hdest Encode::encode($enc, $CRLF);
}

{
	while(@$goodsubs || @$badsubs) {
		my $bsub = shift @$badsubs;
		my $gsub = shift @$goodsubs;
		if($bsub && $bsub->{PAIR}) {
			while(! $gsub->{PAIR}) {
				prsubs($hdest, undef, $gsub);
				$gsub = shift @$goodsubs;
			}
		} elsif($gsub && $gsub->{PAIR}) {
			while(! $bsub->{PAIR}) {
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

	my $s = $sub->{ID} . "<br>";;
	$s .= ParseSrt::ms2str($sub->{START})."<br>";
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
	if($sub1 && $sub1->{PAIR}) {
		$pair = " $sub1->{ID}  $sub2->{ID}";
		$diff = $sub1->{START} - $sub2->{START};
		if(abs($diff) >= 200) {
			$style = 'color: red; font-weight: bold';
		} elsif(abs($diff) >= 100) {
			$style = 'color: red;';
		}
	}
	print $hdest Encode::encode('utf-8', "<tr><td>$ssub1</td><td>$ssub2</td><td style='$style'>$diff</td><td>$pair</td><tr>\n");
}
