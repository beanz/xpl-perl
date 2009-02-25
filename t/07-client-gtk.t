#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use Socket;
use Gtk2 -init;
use Test::More tests => 5;
$|=1;

use_ok("xPL::Gtk2Client");

my $errors;
{
  # This is to override to kill the main loop
  package xPL::Gtk2ClientExit;
  use base qw/xPL::Gtk2Client/;
  sub dispatch_timer {
    my $self = shift;
    $self->SUPER::dispatch_timer(@_);
    Gtk2->main_quit;
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

my $xpl = xPL::Gtk2ClientExit->new(vendor_id => 'acme',
                                   device_id => 'dingus',
                                   ip => "127.0.0.1",
                                   broadcast => "127.255.255.255",
                                  );
ok($xpl, 'constructor');

$xpl->{_send_sin} = sockaddr_in($fake_hub_port, $fake_hub_addr);

wait_for_tick($xpl);

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
interval=5
port=".$xpl->listen_port."
remote-ip=".$xpl->ip."
}
";
is($buf, $hb, "first hbeat content");

sub wait_for_tick {
  my $xpl = shift;

  do { Gtk2->main(); } until ($xpl->hbeat_count == 1);
}

sub fake_hub_response {
  my $xpl = shift;
  my $save_sin = $xpl->{_send_sin};
  # hack send_sin so we can send some responses to ourself
  $xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));
  $xpl->send(@_);
  $xpl->{_send_sin} = $save_sin;
}
