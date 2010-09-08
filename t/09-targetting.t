#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use POSIX qw/uname/;
use Socket;
use t::Helpers qw/test_error test_warn/;
$|=1;

BEGIN {
  require Test::More;
  require xPL::Client; import xPL::Client;

  if ($xPL::Listener::EVENT_LOOP eq 'anyevent') {
    import Test::More
      skip_all => q{AnyEvent's singleton main_loop confuses this test};
    exit;
  }

  import Test::More tests => 8;
}

use_ok("xPL::Hub");

my $hub = xPL::Hub->new(interface => 'lo', port => 0, verbose => 1);
is(scalar $hub->clients, 0, "no clients");

my $dingus = xPL::Client->new(vendor_id => 'acme',
                              device_id => 'dingus',
                              instance_id => 'default',
                              ip => "127.0.0.1",
                              broadcast => "127.255.255.255",
                             );

my $widget = xPL::Client->new(vendor_id => 'acme',
                              device_id => 'widget',
                              instance_id => 'default',
                              ip => "127.0.0.1",
                              broadcast => "127.255.255.255",
                             );
# hacking the send socket to send to the hub
$dingus->{_send_sin} =
  sockaddr_in($hub->listen_port, inet_aton($hub->broadcast));
$widget->{_send_sin} =
  sockaddr_in($hub->listen_port, inet_aton($hub->broadcast));

$dingus->main_loop(1); # send a heatbeat
$hub->main_loop(1);    # hub receives it and responds
$dingus->main_loop(1); # client processes reply
$widget->main_loop(1); # send a heatbeat
$hub->main_loop(1);    # hub receives it and responds
$widget->main_loop(1); # client processes reply
$dingus->main_loop(1); # receives and ignores widget heartbeat

# check that the two clients joined to the test hub.
my @clients = $hub->clients;
is(scalar @clients, 2, "two clients");
ok($dingus->exists_timer("!hbeat"), "hbeat setup - dingus");
ok($widget->exists_timer("!hbeat"), "hbeat setup - widget");

# configure callbacks to receive messages
my $dingus_msg;
$dingus->add_xpl_callback(id => 'test',
                          callback => sub {
                            my %p=@_;
                            return if ($p{message}->class =~ /^hbeat\./);
                            $dingus_msg = $p{message};
                          });
my $widget_msg;
$widget->add_xpl_callback(id => 'test',
                          callback => sub {
                            my %p=@_;
                            return if ($p{message}->class =~ /^hbeat\./);
                            $widget_msg = $p{message};
                          });

$dingus->send(message_type => "xpl-stat", class => "test.test",
              head =>
              {
               source => 'bnz-tester.test', # avoid self_skip tests
               target => 'acme-dingus.default',
              },
              body =>
              [
               test => 'test 1',
              ],
             );
$hub->main_loop(1);    # receive and resend message
$dingus->main_loop(1); # receive message
$widget->main_loop(1); # receive message but ignore

is(ref($dingus_msg), 'xPL::Message', 'dingus_should receive message');
is($dingus_msg->field('test'), 'test 1',
   'dingus_should receive message - content');

is($widget_msg, undef, 'widget should not receive message');
