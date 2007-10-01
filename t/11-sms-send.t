#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 5;
use POSIX qw/strftime/;
use IO::Socket::INET;
use IO::Select;

eval { require SMS::Send; };
my $has_sms_send = !$@;
SKIP: {
  skip 'SMS::Send not available', 5 unless $has_sms_send;

  use_ok('SMS::Send::CSoft');
  use_ok('SMS::Send');
  my $sms = SMS::Send->new('CSoft', _login => 'test', _password => 'pass', _verbose => 0);
  ok($sms);

  my $serv = IO::Socket::INET->new(Listen => 1, LocalAddr => "127.0.0.1",
                                   LocalPort => 0);
  $serv or die "Failed to set up fake HTTP server\n";
  my $port = $serv->sockport;
  #print STDERR "Using port: $port\n";
  my $pid = fork;
  unless ($pid) { server($serv); }
  $serv->close;
  $SMS::Send::CSoft::URL = 'http://127.0.0.1:'.$port.'/';
  ok($sms->send_sms(text => 'text', to => '+441234123456'));
  ok(!$sms->send_sms(text => 'mess', to => '+441234654321'));
  undef $SMS::Send::CSoft::URL;
  waitpid $pid, 0;
}

sub server {
  my $serv = shift;
  my $sel = IO::Select->new($serv);
  $sel->can_read(1) or die "Failed to receive connection\n";
  my $client = $serv->accept;
  my $sel2 = IO::Select->new($client);
  $sel2->can_read(1) or die "Failed to receive request\n";
  my $got;
  my $bytes = $client->sysread($got, 1500);
  $got =~ qr!^POST / HTTP/1\.[01]\r?\n! or die "No POST header\n";
  $got =~ qr!Content-Type: application/x-www-form-urlencoded\r?\n! or
    die "No Content-Type header\n";
  $got =~ qr!Content-Length: 55\r?\n! or die "No Content-Length header\n";
  foreach my $field (qw/PIN=pass Message=text Username=test
                        SendTo=441234123456/) {
    $got =~ quotemeta($field) or die "No field $field\n";
  }
  $client->syswrite("200 OK\nContent-Type: text/plain\n\nMessage Sent OK\n");
  $client->close;

  $sel->can_read(1) or die "Failed to receive connection\n";
  $client = $serv->accept;
  $sel2 = IO::Select->new($client);
  $sel2->can_read(1) or die "Failed to receive request\n";
  $bytes = $client->sysread($got, 1500);
  $got =~ qr!^POST / HTTP/1\.[01]\r?\n! or die "No POST header\n";
  $got =~ qr!Content-Type: application/x-www-form-urlencoded\r?\n! or
    die "No Content-Type header\n";
  $got =~ qr!Content-Length: 55\r?\n! or die "No Content-Length header\n";
  foreach my $field (qw/PIN=pass Message=mess Username=test
                        SendTo=441234654321/) {
    $got =~ quotemeta($field) or die "No field $field\n";
  }
  $client->syswrite("200 OK\nContent-Type: text/plain\n\nOops\n");
  $client->close;

  exit;
}
