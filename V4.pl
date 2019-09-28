#!/usr/bin/perl -X
#####!/usr/bin/env perl
##Vl.8:30 PM Wednesday, May 02, 2018: $ perl -c V4.pl; $ perl ./V4.pl; RO2 (elements) recovering code..
package Foo;
use strict;
# no strict "refs";
use warnings;
use constant REV => "14_2, 6:43 PM Saturday, September 28, 2019";
use v5.14;
sub getCellAliasOrIdx {
  my ($cellmapref, $AliasOrIdx) = @_[0, 1]; #Vl. @a = @{$aref}; ${$aref}[3] == $aref->[3]
  if ($AliasOrIdx =~ /^\d+$/){#Vl. test if is a whole number
      for (my $j = 1; $j < @{$cellmapref}; $j += 2) {return $cellmapref->[$j - 1] if ($cellmapref->[$j] == $AliasOrIdx)}
  } elsif ($AliasOrIdx == 0){ #Vl.Since Perl evaluates any string to 0 if is not a number.
      for (my $j = 0; $j < @{$cellmapref}; $j += 2) {return $cellmapref->[$j + 1] if ($cellmapref->[$j] == $AliasOrIdx)}
  } else {return} #Vl.see np++ issue1
}
sub get_iws {
  my $exp = $_[3];
  $exp->send("ZAHO::NR=2692;\r"); #Vl.get INCORRECT WORKING STATE (iws) alarms
  my @iws; #Vl.(np++)iws array.
  $exp->expect(10, 'EXECUTED');
  my $get1 = $exp->before;
  # say "Vladi INCORRECT WORKING STATE list:\n", $get1;
  push @iws, $1 while $get1 =~ /ALARM\s+(?!HIS)(\S+)/g; #Vl.(?!HIS)tory is not capture.., it is negative lookahead.., (?=xx) is positive lookahead
  my @suspect_iws; #Vl.treat for now only TBCs and TTRXs
  foreach (@iws){
    if (/^(TBC|TTRX).(\d+)/) {
      if (not grep $_ == $2, @{$_[0]}){ #Vl. @{$_[0]} is \@dtcbIdx
  	    $_ .= "-".getCellAliasOrIdx $_[1], $2; #Vl. $_[1] is \@cellmap
  	    push @suspect_iws, $_
  	  }
    }
  }
	if (@{$_[2]}) {#Vld.iws_ignore1
		@iws = listCmp($_[2], \@iws, "diff");
		@suspect_iws = listCmp($_[2], \@suspect_iws, "diff")
	}
  return \@iws, \@suspect_iws	##Vl.returned $iws has aliasis for each $suspect_iws
}
# our $exp;
sub zuscUnit {
  my $unit = shift; my $exp1 = shift;
  print $unit;
	$unit =~ /^(.+)-/; $unit = $1; my $unitCmd = $unit; $unitCmd =~ s/-/,/g;
  # $exp1->log_stdout(1);
  $exp1->send("ZUSI:$unitCmd;\r"); $exp1->clear_accum();
  $exp1->expect(10, 'EXECUTED');
  my $get1 = $exp1->before;
  $get1 =~ /$unit\s+(\S+)/;
  my $state = $1;
	sleep 1; #Vld.a little guard
  if ($state eq "SE-OU"){
    $exp1->send("ZUSC:$unitCmd:TE;\r");
    $exp1->expect(20, 'COMMAND EXECUT');
    $get1 = $exp1->before;
		return undef unless $get1 =~ /NEW STATE = TE-EX/;
		$state = "TE-EX"
  }
	sleep 2;
  if ($state eq "TE-EX"){
    $exp1->send("ZUSC:$unitCmd:WO;\r");
    $exp1->expect(20, 'COMMAND EXECUT');
    $get1 = $exp1->before;
		return undef unless $get1 =~ /NEW STATE = WO-EX/;
		say " ..done.";
    return 1
  }
  # $exp1->log_stdout(0);
  return undef
}

my $Usage = "Usage:\n$0 [--help]\n$0 dxt1|dxt2\n$0 --monitoringRO2 ##Vl.mainly for run as service.\n".
"Other options for service mode in ./V4ref2 config file..\n";
# say "nr params: ", $#ARGV + 1, " @ARGV";
undef my $dxtNum;
undef my $monitoring;
say "..started $0 rev.", REV, ". Current system time is: ".scalar localtime;
die $Usage if (not @ARGV or @ARGV > 1);
for ($ARGV[$#ARGV]){
  no warnings 'experimental';
  die $Usage 		when $_ eq "--help";
  $dxtNum = 1		when $_ eq "dxt1";
  $dxtNum = 2		when $_ eq "dxt2";
  $monitoring = 1	when $_ eq "--monitoringRO2";
  default {die $Usage}
}
use Expect;
push @INC, "../";
require Vutils::Vutils1;
my %opt = (	#Vl.options
    period  => 3, ##minutes
    nnm => "ts dxt$dxtNum:_noNews;; ", ##noNewsMessage
);

sub mainWork1 {#Vl.use external var. $dxtNum
	my (@dxt1S, @dxt2S);
	my (@prev_dtcbIdx, @prev_dtcbIdxAlias, @prev_iws);
	undef my @iws_ignore1;
	my $telnet = "telnet";
	open my $in, '<', "./V4ref2" or die "Can't open the file ./V4ref2: $! .., ##Vl. you should run from V4 directory..\n";
	while (<$in>) {
		last if /comment/;
		next if not validLine();
		# say $_;
		my $cut1;
		if (/Socket/){
				/=\s*(.*$)/; $cut1 = $1;
				push @dxt1S, split /,\s*/, $cut1 if /dxt1/;
				push @dxt2S, split /,\s*/, $cut1 if /dxt2/;
		} elsif (/dtcbIdx(?!Alias)/) {
				/:\s*(.*$)/; $cut1 = $1;
				push @prev_dtcbIdx, split /\s+/, $cut1 if /dxt$dxtNum/;
		} elsif (/dtcbIdx(?=Alias)/) {
				/:\s*(.*$)/; $cut1 = $1;
				push @prev_dtcbIdxAlias, split /\s+/, $cut1 if /dxt$dxtNum/;
		} elsif (/iws_ignore/) {
				/:\s*(.*$)/; $cut1 = $1;
				push @iws_ignore1, split /,\s*/, $cut1 if /dxt$dxtNum/
		} elsif (/iws/) {
				/:\s*(.*$)/; $cut1 = $1;
				push @prev_iws, split /\s+/, $cut1 if /dxt$dxtNum/;
		} elsif (/telnet/) {
				/=\s*(.*$)/;
				$telnet = $1
		} elsif (/period/) {
				/=\s*(.*$)/;
				$opt{period} = $1;
		} elsif (/noNewsM/) {
				/=\s*(.*$)/;
				$opt{nnm} = $1;
				$opt{nnm} =~ s/\$dxtNum/$dxtNum/
		}
	}
	close $in;
	my %dxtS = (1 => \@dxt1S, 2 => \@dxt2S); #Vl.hash of arrays
	open my $hDxtCells, '<', "./dxt$dxtNum"."Cells.txt" or die "Can't open the file ./dxt$dxtNum"."Cells.txt: $!";
	my @cellmap;
	while (<$hDxtCells>) {next if not validLine(); push @cellmap, split(/ +/)}
	close $hDxtCells;
	undef my $timeout;
	undef my $exp;
	$exp = Expect->new($telnet, @{$dxtS{$dxtNum}}); #Vl. @{$aref}
	# $exp->send("\r\n\r\n");
	# say "manual_stty: ", $exp->manual_stty;
	# $exp->debug(2);
	$exp->log_stdout(0);
	$exp->expect(10,
		'-re', "USERNAME <|PASSWORD <", sub {$exp->send("SYSTEM\r"); exp_continue},
					 "< ", sub {$exp->send("ZC?;\r")});
	die "NS - NoSession!!\n" if not defined $monitoring and not defined $exp->match();
	# print "NS" and $exp->hard_close() and return 1 if not defined $exp->match();#very exotic, hard_close() seems don't return true..
	if (not defined $exp->match()) {
		print "NS$dxtNum ";
		$exp->hard_close();
		return 1
	}
	$exp->send("ZAHO::NR=3939;\r"); #Vl.get DXT-TBS CONNECTION BREAK (dtcb) alarms
	$exp->clear_accum();
	$exp->expect(10, 'EXECUTED');
	my $get1 = $exp->before;
	# say "Vladi DXT-TBS CONNECTION BREAK list:\n", $get1;
	my @dtcbIdx; #Vl.(np++)dtcb Indexes array.
	push @dtcbIdx, $1 while $get1 =~ /TBS-(\d+)/g;
	my @dtcbIdxAlias;
	for (my $i = 0; $i < @dtcbIdx; $i++) {
		for (my $j = 1; $j < @cellmap; $j += 2) {
			if ($cellmap[$j] == $dtcbIdx[$i]) {
			push @dtcbIdxAlias, $dtcbIdx[$i];
			push @dtcbIdxAlias, $cellmap[$j - 1];
			last
		}
		}
	}
	my ($iwsref, $suspect_iwsref) = get_iws \@dtcbIdx, \@cellmap, \@iws_ignore1, $exp;
	my $log1 = sub {
		say "\ndxt$dxtNum log, ".scalar localtime;
		# no warnings;
		say "dtcbIdx array: @dtcbIdx";
		say "dtcbIdxAlias array: @dtcbIdxAlias";
		say "iws ignored resources: @iws_ignore1" if @iws_ignore1
	};
	##Vl.recovering & logging..
	my $sChg1 = 0; ##Vl.statusChanged degree from prev. session
	if (my @c = listCmp(\@dtcbIdxAlias, \@prev_dtcbIdxAlias, "diff")){ #Vl. @a = @{$aref}; ${$aref}[3] == $aref->[3]
		print " ", scalar localtime, " dxt$dxtNum:_dtcb-Reestablished: @c;; ";
		$sChg1 |= 0b1
	}
	if (my @c = listCmp(\@prev_dtcbIdxAlias, \@dtcbIdxAlias, "diff")){
		print " ", scalar localtime, " dxt$dxtNum:" if not $sChg1;
		print "_dtcb-new_faults: @c;; ";
		$sChg1 |= 0b10
	}
	if (my @c = listCmp($iwsref, \@prev_iws, "diff")){
		my @ar; ##Vl.AutoRecovered
		foreach (@c) {
			/^.*?-(\d+)/; #Vl.non-greedy
			push @ar, $_ if not grep $1 == $_, @prev_dtcbIdx
		}
		print " ", scalar localtime, " dxt$dxtNum:" if @ar and not $sChg1;
		print "_iws-AutoRecovered: @ar;; " if @ar;
		$sChg1 |= 0b100
	}
	$sChg1 |= 0b1000 if listCmp(\@prev_iws, $iwsref, "diff");
	if ($monitoring and $opt{nnm} and not @{$suspect_iwsref} and not $sChg1 and @dtcbIdx == @prev_dtcbIdx and not listCmp(\@dtcbIdx, \@prev_dtcbIdx, "diff")){
		print scalar localtime if $opt{nnm} =~ /^ts/;
		$opt{nnm} =~ s/^ts\s+//;
		print $opt{nnm}
	}
	if (not $monitoring and not @{$suspect_iwsref}) {&$log1; say "iws array: @{$iwsref}"}
	if (@{$suspect_iwsref}) {
		&$log1;
		my @iiws = @{$iwsref}; #Vld.initial iws, case dxt2 log, Sun Jun  3 06:43:43 2018 in V4log1 file
		say "initial iws array: @{$iwsref}";
		foreach (@{$suspect_iwsref}) {say "  ..Fail to zusc the unit $_ .." if not zuscUnit $_, $exp}
		($iwsref, $suspect_iwsref) = get_iws \@dtcbIdx, \@cellmap, \@iws_ignore1, $exp;
		say "..final iws array: @{$iwsref}\n";
		$sChg1 |= 0b100 if @{$iwsref} != @iiws
	}
	$exp->send("Z;\r");
	$exp->send("Z;\r"); #should exit here..
	# print "dtcbIdx array: @dtcbIdx"
	# say "progam arguments: @ARGV";
	if ($sChg1){
		open $in, '<', "./V4ref2" or die "Can't open the file ./V4ref2: $!";
		open my $out, '>', "./V4ref2new" or die "Can't open the file ./V4ref2new: $!";
		while (<$in>) {
			undef my $flag;
			if (/^\s*dxt$dxtNum(?=_)/) {
				/(^\s*.*?:\s*)/; my $entry = $1; ##Vl.non-greedy
				if (/dtcbIdx(?!Alias)/ and $sChg1 & 0b11) {say $out $entry."@dtcbIdx ##Vl. ".scalar localtime; $flag = 1}
				if (/dtcbIdxAlias/ and $sChg1 & 0b11) {say $out $entry."@dtcbIdxAlias ##Vl. ".scalar localtime; $flag = 1}
				if (/iws(?!_ignore)/ and $sChg1 >= 4) {say $out $entry."@{$iwsref} ##Vl. ".scalar localtime; $flag = 1}
			}
			print $out $_ unless $flag
		}
		close $in;
		close $out; unlink $in; rename "./V4ref2new", "./V4ref2";
	}
}

if ($monitoring){
  while () {
    $dxtNum = 1;
		mainWork1;
		sleep $opt{period} * 12;
    $dxtNum = 2;
		mainWork1;
		sleep $opt{period} * 60
  }
}
mainWork1;

=begin comment1

Issues:
issue1: parameter-less return has the magic feature that in scalar context it returns undef, but in list context it returns an empty list (). https://perlmaven.com/how-to-return-undef-from-a-function

batwings@VladiLaptopWXP /home/batwings/projects/perl/V4_DXTtelnet
$ perl -X ./V4.pl dxt2
..started ./V4.pl rev.3, 10:20 PM Thursday, May 03, 2018
started ./V4.pl rev.3, 10:20 PM Thursday, May 03, 2018
manual_stty: 0
dtcbIdx array: 66 35 84
dtcbIdxAlias array: 66 NADRAG 35 ROSIUTA 84 TOROIOAGA
iws array: TBC-66-0 TTRX-13-0 TTRX-13-1 CLS-0 TDSC-72-0 TDSC-75-0 TBC-84-0 TTRX-84-0 TDSC-1-0 TDSC-62-0

=end comment1

=cut

