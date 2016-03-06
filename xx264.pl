#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long; # qw(:config pass_through);
use Data::Dumper;
use POSIX qw(strftime);

my %def_opts = (
	'b-adapt' => 2, # make optimal B-frames choosing
	'me' => 'umh',
	'crf' => '18', # optimal for SD and HD
	'+no-fast-pskip' => 1, # Recommended for crf
	'bframes' => 8, # Actual value get from test encoding
	'rc-lookahead' => 50, # perharps optimal. Default 40.
	'trellis' => 2, # Optimal
	'ref' => 16, # 1080p - 4, 720p - 9, SD - <= 16
	'subme' => 10, # best
	'merange' => 24, # 16 - default. Not usefull above 32
	'deblock' => '-1:-1', # film tune
	'aq-mode' => 2, # better fades
	'+no-mbtree' => 1, # mbtree not good with aq=2
	'output' => undef,
	'psy-rd' => undef,
	'aq-strength' => undef,
	'no-dct-decimate' => undef,
	'ipratio' => undef,
	'pbratio' => undef,
	'qcomp' => undef,
	'direct' => undef,
	'sar' => undef,
);

my %sar_str = (
	ntsc16 => '32:27',
	ntsc4 => '8:9',
	pal16 => '64:45',
	pal4 => '16:15',
);

my %long_args;
foreach my $name (keys %def_opts) {
	if($name =~ /^\+/) {
		$long_args{substr($name, 1) . "!"} = \$def_opts{$name};
	} else {
		$long_args{"$name=s"} = \$def_opts{$name};
	}
}
my $no_idle = 0;
$long_args{'no-idle!'} = \$no_idle;
my $overwrite = 0;
$long_args{'overwrite!'} = \$no_idle;


GetOptions(%long_args) or die;

do_nice() unless($no_idle);

# input/output
my $input = shift @ARGV || 'demux.avs';
$input .= ".avs" if $input !~ /\.\w{3}$/;
unless($def_opts{output}) {
	my $output = $input;
	$output =~ s/\.\w{3}$/.mkv/;
	$def_opts{output} = $output;
}
$def_opts{output} .= ".mkv" if $def_opts{output} !~ /\.\w{3}$/;

if(-e $def_opts{output} && ! $overwrite) {
	die "File '$def_opts{output}' already exists\n";
}

# log
my $log = $def_opts{output};
$log =~ s/\.mkv$/.x264.log/;

# sar
if($def_opts{sar} && exists $sar_str{$def_opts{sar}}) {
	$def_opts{sar} = $sar_str{$def_opts{sar}};
}

# print Dumper(\%def_opts); exit; # FIXME

my @args = ('x264');
#@args = "xx264.pl"; # FIXME
foreach my $name (sort keys %def_opts) {
	if($name =~ /^\+/) {
		if($def_opts{$name}) {
			push(@args, "--" . substr($name, 1));
		}
	} elsif($def_opts{$name}) {
		push(@args, "--$name $def_opts{$name}");
	}
}
push(@args, $input);
my $cmdline = join(" ", @args, "2>&1");

open(my $hlog, ">$log") or die "open($log): $!";
binmode $hlog;

printf $hlog "Started %s\n\n", strftime("%Y-%m-%d %H:%M:%S", localtime());
my $starttime = time;

print $hlog "$cmdline\n\n";

open(my $hcmd, "$cmdline |") or die "cmd($cmdline): $!";
binmode $hcmd;
my $buf = '';
while(!eof($hcmd)) {
	read($hcmd, my $str, 100);
	$buf .= $str;
	while(my($line) = $buf =~ /^([^\r\n]*?[\r\n]+)/) {
		next if $line =~ /^\[\d+\.\d+%\]/ || $line =~ /^ +\r$/;
		next if $line =~ /^\d+ frames:/;
		print $hlog "$line" unless $line =~ /^\[\d+\.\d+%\]/ || $line =~ /^ +\r$/;
	} continue {
		$buf =~ s/^[^\r\n]*?[\r\n]+//;
	}
}
print $hlog $buf;
close($hcmd);

my $dur = time - $starttime;
printf $hlog "\nFinished %s (%dd %02dh %02dm)\n",
	strftime("%Y-%m-%d %H:%M:%S", localtime()),
	int($dur /3600 / 24),
	int($dur / 3600) % 24,
	int($dur / 60) % 60,
;

close($hlog);

sub do_nice {
	if ($^O eq "MSWin32") {
		require Win32;
		require Win32::Process;
		Win32::Process::Open(my $proc, $$, 0) or die Win32::ErrorReport();
		$proc->SetPriorityClass(Win32::Process::IDLE_PRIORITY_CLASS()) or die Win32::ErrorReport();
	} elsif ($^O eq "linux") {
		require POSIX;
		POSIX::nice(19);
	} else {
		die "Unexpected OS $^O";
	}
}
