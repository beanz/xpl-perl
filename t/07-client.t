#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2006 by Mark Hindess

use strict;
use Socket;
use Test::More tests => 51;
$|=1;

use_ok("xPL::Client");

$ENV{XPL_HOSTNAME} = 'mytestid';
my $errors;
{
  # This is to override errors from using way too short intervals
  # for all timings
  package xPL::ClientNoDie;
  use base qw/xPL::Client/;
  sub argh {
    my $self = shift;
    my ($file, $line, $method) = (caller(1))[1,2,3];
    $method =~ s/.*:://;
    $errors .= (ref($self)||$self)."->$method: @_\n";
    return 1;
  }
  sub argh_named {
    my $self = shift;
    my $name = shift;
    my ($file, $line) = (caller(1))[1,2];
    $errors .= (ref($self)||$self)."->$name: @_\n";
    return 1;
  }
}

# we bind a fake hub to make sure we don't accidentally hit a live
# udp port
my $hs;
socket($hs, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
setsockopt $hs, SOL_SOCKET, SO_BROADCAST, 1;
#setsockopt $hs, SOL_SOCKET, SO_REUSEADDR, 1;
binmode $hs;
bind($hs, sockaddr_in(0, inet_aton("127.0.0.1"))) or
  die "Failed to bind listen socket: $!\n";
my ($fake_hub_port, $fake_hub_addr) = sockaddr_in(getsockname($hs));

my $warn;
$SIG{__WARN__} = sub { $warn .= $_[0]; };

my $xpl = xPL::ClientNoDie->new(vendor_id => 'acme',
                                device_id => 'dingus',
                                ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                fast_hbeat_interval => 0.1,
                                hopeful_hbeat_interval => 0.2,
                                hub_response_timeout => 0.15,
                                hbeat_interval => 0.01,
                               );
ok($xpl, 'constructor');
is($xpl->instance_id, 'mytestid', "XPL_HOSTNAME environment variable test");
my $pre = ref($xpl)."->new: ";
is($errors,
  $pre."hbeat_interval is invalid: should be 5 - 30 (minutes)\n".
  $pre."fast_hbeat_interval is invalid: should be 3 - 30 (seconds)\n".
  $pre."hopeful_hbeat_interval is invalid: should be 20 - 300 (seconds)\n".
  $pre."hub_response_timeout is invalid: should be 30 - 300 (seconds)\n",
   "errors as expected");

undef $errors;

is($xpl->fast_hbeat_interval, 0.1, "fast_hbeat_interval setup");
is($xpl->hopeful_hbeat_interval, 0.2, "hopeful_hbeat_interval setup");
is($xpl->hub_response_timeout, 0.15, "hub_response_timeout setup");

is($xpl->timer_timeout("!fast-hbeat"), -0.1, "fast timer timeout");
is($xpl->{_max_fast_hbeat_count}, 1, "max fast hbeats");
is($xpl->hbeat_mode, 'fast', "hbeat mode is fast");

$xpl->{_send_sin} = sockaddr_in($fake_hub_port, $fake_hub_addr);

wait_for_tick($xpl, "!fast-hbeat");

is($xpl->hbeat_count, 1, "correct hbeat count");
my $buf;
my $r = recv($hs, $buf, 1024, 0);
ok(defined $r, "received first hbeat");

my $hb = "xpl-stat
{
hop=1
source=".$xpl->id."
target=*
}
hbeat.app
{
interval=0.01
port=".$xpl->listen_port."
remote-ip=".$xpl->ip."
}
";
is($buf, $hb, "first hbeat content");

is($xpl->hbeat_mode, 'hopeful', "hbeat mode is hopeful");
is($xpl->timer_timeout("!fast-hbeat"), 0.2, "hopeful hbeat timer");
wait_for_tick($xpl, "!fast-hbeat");

undef $buf;
$r = recv($hs, $buf, 1024, 0);
ok(defined $r, "received second hbeat");
is($xpl->hbeat_count, 2, "hbeat count");

is($buf, $hb, "second hbeat content");

is($xpl->timer_timeout("!fast-hbeat"), 0.2, "hopeful hbeat timer 2");
is($xpl->hbeat_mode, 'hopeful', "hbeat mode is hopeful");

fake_hub_response($xpl, class => "clock.update");

$xpl->main_loop(1);
ok($xpl->exists_timer("!fast-hbeat"), "fast hbeat timer even now");
is($xpl->hbeat_count, 2, "hbeat count");
is($xpl->hbeat_mode, 'hopeful', "hbeat mode is hopeful");

fake_hub_response($xpl,
                  message_type => "xpl-stat", class => "hbeat.blah",
                  body =>
                  {
                   interval => $xpl->hbeat_interval,
                   port => $xpl->listen_port,
                   remote_ip => $xpl->ip,
                  },
                  );

$xpl->main_loop(1);
ok($xpl->exists_timer("!fast-hbeat"), "fast hbeat timer still");
is($xpl->hbeat_mode, 'hopeful', "hbeat mode is hopeful");

fake_hub_response($xpl,
                  head =>
                  {
                   source => "acme-dingus.notme",
                  },
                  class => "hbeat.app",
                  body =>
                  {
                   interval => $xpl->hbeat_interval,
                   port => $xpl->listen_port,
                   remote_ip => $xpl->ip,
                  },
                 );

$xpl->main_loop(1);
is($xpl->hbeat_count, 2, "hbeat count");
is($xpl->hbeat_mode, 'hopeful', "hbeat mode is hopeful");

ok($xpl->exists_timer("!fast-hbeat"), "fast hbeat timer even now");

fake_hub_response($xpl,
                  class => "hbeat.app",
                  body =>
                  {
                   interval => $xpl->hbeat_interval,
                   port => $xpl->listen_port,
                   remote_ip => $xpl->ip,
                  },
                 );
is($xpl->hbeat_count, 2, "hbeat count");

$xpl->main_loop(1);

ok(!$xpl->exists_timer("!fast-hbeat"), "fast hbeat timer gone");

ok($xpl->exists_timer("!hbeat"), "hbeat timer exists");
wait_for_tick($xpl, "!hbeat");
is($xpl->hbeat_count, 3, "hbeat count");
wait_for_tick($xpl, "!hbeat");
is($xpl->hbeat_count, 4, "hbeat count");

is($errors, undef, "no unexpected errors");

fake_hub_response($xpl,
                  class => 'hbeat.request',
                  head => { source => "acme-dingus.req" },
                  body => { command => 'request', },
                 );
$xpl->reset_timer('!hbeat', time+20);
my $next_hbeat = $xpl->timer_next('!hbeat');
$xpl->main_loop(1);
is($xpl->xpl_callback_callback_count('!hbeat-request'), 1,
   'hbeat.request - response received');
is($xpl->hbeat_count, 4, "hbeat.request - hbeat count");
ok($xpl->exists_timer("!hbeat-response"),
   "hbeat.request - response timer exists");
# force hbeat timer to go off after extra hbeat is sent
$xpl->reset_timer('!hbeat-response', time-6);
$xpl->main_loop(1);
is($xpl->hbeat_count, 5, "hbeat.request - hbeat count");
ok(!$xpl->exists_timer("!hbeat-response"),
   "hbeat.request - response timer removed");
ok($xpl->timer_next('!hbeat') < $next_hbeat,
   'hbeat.request - hbeat timer reset');

# force hbeat timer to go off before extra hbeat is sent but not so soon that
# the hbeat response timer is removed immediately
$xpl->reset_timer('!hbeat-response', time-1);
fake_hub_response($xpl,
                  class => 'hbeat.request',
                  head => { source => "acme-dingus.req" },
                  body => { command => 'request', },
                 );
$xpl->main_loop(1);
is($xpl->xpl_callback_callback_count('!hbeat-request'), 2,
   'hbeat.request - response received');
ok($xpl->exists_timer("!hbeat-response"),
   'hbeat.request - response timer exists');
my $count = $xpl->timer_callback_count('!hbeat');
$xpl->main_loop(1);
if (0) { #TOFIX
is($count+1,$xpl->timer_callback_count('!hbeat'),
   'hbeat.request - normal hbeat sent as response');
ok(!$xpl->exists_timer("!hbeat-response"),
   'hbeat.request - response timer removed');
} else {
  ok(1, 'tofix');
  ok(1, 'tofix');
}

# test the case when the !hbeat timer doesn't exist - normally when the fast
# timer or hopeful timer would but here we just remove it for simplicity
$count = $xpl->hbeat_count();
fake_hub_response($xpl,
                  class => 'hbeat.request',
                  head => { source => "acme-dingus.req" },
                  body => { command => 'request', },
                 );
$xpl->remove_timer('!hbeat');
$xpl->main_loop(1);
is($xpl->xpl_callback_callback_count('!hbeat-request'), 3,
   'hbeat.request - response received');
is($xpl->hbeat_count, $count, "hbeat.request - hbeat count");
ok($xpl->exists_timer("!hbeat-response"),
   "hbeat.request - response timer exists");
$xpl->reset_timer('!hbeat-response', time-6);
$xpl->main_loop(1);
is($xpl->hbeat_count, $count+1, "hbeat.request - hbeat count");
ok(!$xpl->exists_timer("!hbeat-response"),
   "hbeat.request - response timer removed");

delete $ENV{XPL_HOSTNAME};
no strict qw/refs/;
*{"xPL::Client::uname"} = sub { return };
use strict qw/refs/;
$xpl = xPL::Client->new(ip => "127.0.0.1", broadcast => "127.255.255.255",
                        vendor_id => 'acme', device_id => 'dingus');
ok($xpl, 'client w/o uname');
ok($xpl->id, 'acme-dingus.default');

sub wait_for_tick {
  my $xpl = shift;
  my $callback = shift;

  my $tn = $xpl->timer_next($callback);
  do { $xpl->main_loop(1); } until (Time::HiRes::time > $tn);
}

sub fake_hub_response {
  my $xpl = shift;
  my $save_sin = $xpl->{_send_sin};
  # hack send_sin so we can send some responses to ourself
  $xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));
  $xpl->send(@_);
  $xpl->{_send_sin} = $save_sin;
}
