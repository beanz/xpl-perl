#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 11;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','Linux');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
  my $msg;
  if (scalar @_ == 1) {
    $msg = shift;
  } else {
    eval {
      my %p = @_;
      $p{head}->{source} = $self->id if ($self->can('id') &&
                                         !exists $p{head}->{source});
      $msg = xPL::Message->new(%p);
      # don't think this can happen: return undef unless ($msg);
    };
    $self->argh("message error: $@") if ($@);
  }
  $msg;
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--linux-verbose');
  $xpl = xPL::Dock->new(port => 0);
}
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Linux', 'plugin has correct type');

no warnings;
$xPL::Dock::Linux::FILE_PREFIX = 't/linux/1';
use warnings;
no warnings qw/deprecated/;

my $dir = 't/linux/1/sys/class/power_supply';
mkdir $dir.'/BAT4';
my $unreadable = $dir.'/BAT4/charge_full';
open my $f, '>'.$unreadable or
  die "Failed to open temporary file $unreadable: $!\n";
close $f;
chmod 0, $unreadable;
mkdir $dir.'/AC2';
my $unreadable2 = $dir.'/AC2/online';
open $f, '>'.$unreadable2 or
  die "Failed to open temporary file $unreadable2: $!\n";
close $f;
chmod 0, $unreadable2;
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "mytestid-ac mains (1)\nmytestid-bat0/battery/98.13/%\n", 'first output');
unlink $unreadable;
unlink $unreadable2;
rmdir $dir.'/AC2';
rmdir $dir.'/BAT4';

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-bat0',
                 type => 'battery',
                 current => '98.13',
                 units => '%',
                ],
               }, 'checking xPL message - bat0 trig');

no warnings;
$xPL::Dock::Linux::FILE_PREFIX = 't/linux/2';
use warnings;

is(test_output(sub { $xpl->dispatch_timer('linux!'.$plugin); }, \*STDOUT),
   '', 'second output - no change/no output');

check_sent_msg({
                message_type => 'xpl-stat',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-bat0',
                 type => 'battery',
                 current => '98.13',
                 units => '%',
                ],
               }, 'checking xPL message - bat0 stat');

no warnings;
$xPL::Dock::Linux::FILE_PREFIX = 't/linux/3';
use warnings;

is(test_output(sub { $xpl->dispatch_timer('linux!'.$plugin); }, \*STDOUT),
   "mytestid-ac battery (0)\nmytestid-bat0/battery/8.33/%\n", 'third output');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'ups.basic',
                body =>
                [
                 status => 'battery',
                 event => 'onbattery',
                ],
               }, 'checking xPL message - ac trig');
check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-bat0',
                 type => 'battery',
                 current => '8.33',
                 units => '%',
                ],
               }, 'checking xPL message - bat0 trig');

is_deeply(xPL::Dock::Linux::dir_entries('/non-existent'), [],
          'non-existent directory');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is_deeply(\%m, $expected, $desc);
}
