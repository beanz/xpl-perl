#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use DirHandle;
use English qw/-no_match_vars/;
use FileHandle;
my %msg;

my $EMPTY = q{};
my $COMMA = q{,};
my $OPEN_B = q{(};
my $CLOSE_B = q{)};

BEGIN {
  my $SLASH = q{/};
  my $tests = 1;
  my $dir = 't/msg';
  my $dh = DirHandle->new($dir) or die "Open of $dir directory: $ERRNO\n";
  foreach (sort $dh->read) {
    next if (!/^(.*)\.txt$/);
    my $name = $LAST_PAREN_MATCH;
    my $f = $dir.$SLASH.$_;
    my $fh = FileHandle->new($f) or die "Failed to open $f: $ERRNO\n";
    local $RS = "\n\n";
    my ($args, $string, @methods) = <$fh>;
    chomp $string;
    chomp @methods;
    $msg{$name} =
      {
       args => $args,
       str => $string,
       methods => \@methods,
      };
    $tests += 8 + 2*(scalar @methods);
    $fh->close;
  }
  $dh->close;
  require Test::More;
  import Test::More tests => $tests;
}

use_ok('xPL::Message');

foreach my $m (sort keys %msg) {
  my $rec = $msg{$m};
  my $args;
  my $args_str = $rec->{args};
  eval $args_str;
  is($EVAL_ERROR, $EMPTY, $m.' - arguments created with no warnings');
  ok(defined $args && (ref $args) eq 'HASH', $m.' - test args read');
  my $msg;
  eval { $msg = xPL::Message->new(%{$args}); };
  is($EVAL_ERROR, $EMPTY, $m.' - message created with no warnings');
  ok($msg, $m.' - message created');
  my $str = $msg->string;
  chomp $str;
  is($str, $rec->{str}, $m.' - message string check');
  my $msg2;
  eval { $msg2 = xPL::Message->new_from_payload($str."\n"); };
  is($EVAL_ERROR, $EMPTY,
     $m.' - message created from string with no warnings');
  ok($msg, $m.' - message created from string');
  my $str2 = $msg->string;
  chomp $str2;
  is($str2, $rec->{str}, $m.' - message string check2');
  foreach my $m_str (@{$msg{$m}->{methods}}) {
    my ($method, $expected_result) = split /=/, $m_str, 2;
    my $expected_error;
    chomp $expected_result;
    if ($expected_result =~ /^(.*?)\n(.*)$/ms) {
      $expected_result = $1;
      $expected_error = $2;
    }
    my @args;
    if ($method =~s/\[(.*)\]//) {
      @args = split $COMMA, $LAST_PAREN_MATCH;
    }
    my $result;
    my $error;
    eval {
      local $SIG{__WARN__} = sub { $error = shift; return 1; };
      $result = $msg->$method(@args);
    };
    unless (defined $result) {
      $result = 'undef';
    }
    if (ref($result) eq 'ARRAY') {
      $result = '['.(join ',', @$result).']';
    }
    if ($EVAL_ERROR) {
      $error = $EVAL_ERROR;
    }
    is($result, $expected_result,
       $m.' - message->'.$method.$OPEN_B.(join $COMMA, @args).$CLOSE_B);
    if (defined $error) {
      $error =~ s/\s+at \S+ line \d+\.?\s*$//m;
    }
    is($error, $expected_error,
       $m.' - error from message->'.$method.
       $OPEN_B.(join $COMMA, @args).$CLOSE_B);
  }
}
