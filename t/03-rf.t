#!/usr/bin/perl -w
#
# Copyright (C) 2007, 2009 by Mark Hindess

use strict;
use DirHandle;
use English qw/-no_match_vars/;
use t::Helpers qw/test_warn test_error/;
use FileHandle;
my %msg;

my $EMPTY = q{};
my $COMMA = q{,};
my $OPEN_B = q{(};
my $CLOSE_B = q{)};

BEGIN {
  my $SLASH = q{/};
  my $tests = 1;
  my $dir = 't/rf';
  my $dh = DirHandle->new($dir) or die "Open of $dir directory: $ERRNO\n";
  foreach (sort $dh->read) {
    next if (!/^(.*)\.txt$/);
    my $name = $LAST_PAREN_MATCH;
    my $f = $dir.$SLASH.$_;
    my $fh = FileHandle->new($f) or die "Failed to open $f: $ERRNO\n";
    local $RS = "\n\n";
    my ($message, $length, $count, $string, $warn, $flags) = <$fh>;
    chomp $message;
    chomp $count;
    chomp $length;
    $string =~ s/\n+$//;
    $warn && $warn =~ s/\n+$//;
    $flags && chomp $flags;
    $msg{$name} =
      {
       msg => $message,
       len => $length,
       count => $count,
       string => $string,
       warn => $warn,
       flags => $flags,
      };
    $tests += 4;
    $fh->close;
  }
  $dh->close;
  require Test::More;
  import Test::More tests => $tests;
}

use_ok('xPL::RF');

my $rf = xPL::RF->new();
foreach my $m (sort keys %msg) {
  my $rec = $msg{$m};
  my $res;
  if ($rec->{flags} && $rec->{flags} =~ s/^pause//) {
    select undef, undef, undef, 1.1;
  }
  if ($rec->{flags} && $rec->{flags} =~ s/^clear//) {
    $rf->stash('unit_cache', {}); # clear unit code cache and try again
    $rf->{_cache} = {}; # clear duplicate cache to avoid hitting it
  }

  my $w = test_warn( sub { $res = $rf->process_variable_length(pack "H*",
                                                                $rec->{msg});
                          });
  is($w||"none\n", $rec->{warn} ? $rec->{warn}."\n" : "none\n",
     $m.' - test warning');

  my $length = $res ? $res->{length}.' bytes' : 'undef';
  my $count = $res ? scalar @{$res->{messages}||[]}.' messages' : 'undef';
  is($length, $rec->{len}, $m.' - correct number of bytes');
  is($count, $rec->{count}, $m.' - correct number of messages');
  my $string = 'empty';
  if (defined $res) {
    if (@{$res->{messages}||[]}) {
      $string = $EMPTY;
      foreach (@{$res->{messages}}) {
        my $msg = xPL::Message->new(head => {source => 'bnz-rftest.default'},
                                    message_type => 'xpl-trig', %$_);
        $string .= $msg->string;
      }
    }
  } else {
    $string = 'undef'
  }
  chomp($string);
  is($string, $rec->{string}, $m.' - correct messages');
}
