#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use English qw/-no_match_vars/;
use t::Helpers qw/test_warn test_error/;
my %msg;

my $EMPTY = q{};
my $COMMA = q{,};
my $OPEN_B = q{(};
my $CLOSE_B = q{)};

BEGIN {
  my $SLASH = q{/};
  my $tests = 1;
  my $dir = 't/x10';
  opendir my $dh, $dir or die "Open of $dir directory: $ERRNO\n";
  foreach (sort readdir $dh) {
    next if (!/^(.*)\.txt$/);
    my $name = $LAST_PAREN_MATCH;
    my $f = $dir.$SLASH.$_;
    open my $fh, '<', $f or die "Failed to open $f: $ERRNO\n";
    local $RS = "\n\n";
    my ($rf, $warn_from_rf, $string, $warn_to_rf) = <$fh>;
    $rf =~ s/\n+$//;
    $warn_from_rf =~ s/\n+$//;
    $string =~ s/\n+$//;
    $warn_to_rf && $warn_to_rf =~ s/\n+$//;
    $msg{$name} =
      {
       rf => $rf,
       string => $string,
       warn_from_rf => $warn_from_rf,
       warn_to_rf => $warn_to_rf,
      };
    $tests += 6;
    close $fh;
  }
  closedir $dh;
  require Test::More;
  import Test::More tests => $tests;
}

use_ok('xPL::X10');

foreach my $m (sort keys %msg) {
  my $rec = $msg{$m};
  my $res;

  my $bytes = [unpack "C*", pack "H*", $rec->{rf}];
  ok(xPL::X10::is_x10($bytes), $m.' - reverse is X10');

  my $w = test_warn( sub { $res = xPL::X10::from_rf($bytes) } );
  is($w||"none\n", $rec->{warn_from_rf} ? $rec->{warn_from_rf}."\n" : "none\n",
     $m.' - test warning');

  my $string = 'empty';
  if (defined $res) {
    $string = $EMPTY;
    foreach (sort keys %$res) {
      $string .= $_."=".$res->{$_}."\n";
    }
  } else {
    $string = 'undef'
  }
  chomp($string);
  is($string, $rec->{string}, $m.' - correct messages');

  $w =
    test_warn(sub {
                $res = xPL::X10::to_rf(%$res);
              });
  is($w||"none\n", $rec->{warn_to_rf} ? $rec->{warn_to_rf}."\n" : "none\n",
     $m.' - test warning');

  my $exp = $rec->{rf}.' '.sprintf("%08b %08b %08b %08b",
                                   unpack "C*", pack "H*",$rec->{rf});
  my $got = (unpack "H*", pack "C*", @$res).' '.sprintf("%08b %08b %08b %08b",
                                                        @$res);
  is($got, $exp, $m.' - correct reverse message');
  ok(xPL::X10::is_x10($res), $m.' - reverse is X10');
}
