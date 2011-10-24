#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use AnyEvent;
use Test::More tests => 5;
use t::Helpers qw/test_warn test_error test_output wait_for_variable/;
use lib 't/lib';

$|=1;

$ENV{PATH} = 't/bin:'.$ENV{PATH};
$ENV{XPL_PLUGIN_TO_WRAP} = 'xPL::Dock::SMART';
use_ok('xPL::Dock','Wrap');

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
                 '--interface' => 'lo',
                 '--define' => 'hubless=1',
                 '--smart-dev-root' => 't/dev',
                 '--smart-verbose');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock smart client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Wrap', 'plugin has correct type');

$xpl->main_loop(3);

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-disk-sda',
                 type => 'temp',
                 current => '43',
                ],
               }, 'checking xPL message - sda trig');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is_deeply(\%m, $expected, $desc);
}
