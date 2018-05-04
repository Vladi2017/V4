#!/usr/bin/env perl
##Vl.8:30 PM Wednesday, May 02, 2018: $ perl -c V4.pl; $ perl ./V4.pl; RO2 (elements) recovering code..
use strict;
# no strict "refs";
use warnings;
use constant REV => "3, 10:20 PM Thursday, May 03, 2018";
use v5.14;
sub getCellAliasOrIdx {
  my ($cellmapref, $AliasOrIdx) = @_[0, 1]; #Vl. @a = @{$aref}; ${$aref}[3] == $aref->[3]
  if ($AliasOrIdx =~ /^\d+$/){#Vl. test if is a whole number
      for (my $j = 1; $j < @{$cellmapref}; $j += 2) {return $cellmapref->[$j - 1] if ($cellmapref->[$j] == $AliasOrIdx)}
  } elsif ($AliasOrIdx == 0){ #Vl.Since Perl evaluates any string to 0 if is not a number.
      for (my $j = 0; $j < @{$cellmapref}; $j += 2) {return $cellmapref->[$j + 1] if ($cellmapref->[$j] == $AliasOrIdx)}
  } else {return} #Vl.see np++ issue1
}
use Expect;
my @dxt1 = ("10.1.153.4", 5001); #Vl.work both "5001" and (int) 5001
my @dxt2 = ("10.1.153.4", 5002);
my %dxt = (1 => \@dxt1, 2 => \@dxt2); #Vl.hash of arrays
undef my $dxtNum;
undef my $monitoring;
my $Usage = "Usage:\n$0 [--help]\n$0 dxt1|dxt2\n$0 --monitoringRO2\n";
# say "nr params: ", $#ARGV + 1, " @ARGV";
say "..started $0 rev.", REV;
die $Usage if (not @ARGV or @ARGV > 1);
for ($ARGV[$#ARGV]){
  die $Usage 		when $_ eq "--help";
  $dxtNum = 1		when $_ eq "dxt1";
  $dxtNum = 2		when $_ eq "dxt2";
  $monitoring = 1	when $_ eq "--monitoringRO2";
  default {die $Usage}
}
open my $handle1, '<', "./dxt$dxtNum"."Cells.txt" or die "Can't open the file ./dxt$dxtNum"."Cells.txt: $!";
my @cellmap;
while (<$handle1>) {chomp; push @cellmap, split(/ +/)} #Vl.avoid \n on last field
close $handle1;
undef my $timeout;
say "started $0 rev.", REV;
my $exp = Expect->new("telnet", @{$dxt{$dxtNum}}); #Vl. @{$aref}
# $exp->send("\r\n\r\n");
say "manual_stty: ", $exp->manual_stty;
$exp->log_stdout(0);
$exp->expect($timeout,
  '-re', "USERNAME <|PASSWORD <", sub {$exp->send("SYSTEM\r"); exp_continue},
         "< ", sub {$exp->send("ZC?;\r")});
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
$exp->send("ZAHO::NR=2692;\r"); #Vl.get INCORRECT WORKING STATE (iws) alarms
my @iws; #Vl.(np++)iws array.
$exp->expect(10, 'EXECUTED');
$get1 = $exp->before;
# say "Vladi INCORRECT WORKING STATE list:\n", $get1;
push @iws, $1 while $get1 =~ /ALARM\s+(?!HIS)(\S+)/g; #Vl.(?!HIS) is not capture.., it is negative lookahead.., (?=xx) is positive lookahead
$exp->send("Z;\r");
$exp->send("Z;\r"); #should exit here..
foreach (@iws){
  if (/^(TBC|TTRX).(\d+)/) {
    my @test1 = grep $_ == $2, @dtcbIdx;
	say "test1_arr: @test1";
    $_ .= "_".getCellAliasOrIdx \@cellmap, $2 unless (grep $2, @dtcbIdx)
  }
}
say "dtcbIdx array: @dtcbIdx";
say "dtcbIdxAlias array: @dtcbIdxAlias";
say "iws array: @iws";
# print "dtcbIdx array: @dtcbIdx"

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

