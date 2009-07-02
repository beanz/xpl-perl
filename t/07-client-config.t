#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Socket;
use Test::More tests => 18;
use File::Temp qw/tempdir/;
use t::Helpers qw/test_error test_warn test_output/;

my $dir = tempdir(CLEANUP => 1);
$ENV{XPL_CONFIG_PATH} = $dir;
push @INC, 't/config';
$ENV{XPL_HOSTNAME} = 'mytestid';

use_ok('xPL::Client');

my @msg;
sub xPL::Client::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

my $xpl = xPL::Client->new(vendor_id => 'acme', device_id => 'config',
                           instance_id => 'test', ip => "127.0.0.1",
                           broadcast => "127.255.255.255",
                           port => 0,
                          );
ok($xpl, 'constructor');
ok($xpl->has_config(), 'has_config()');
is($xpl->needs_config(), 2, 'needs_config()');


my $msg =
  xPL::Message->new(message_type => 'xpl-cmnd',
                    head => { source => 'acme-config.tester' },
                    class => 'config.list',
                    body => { command => 'request' });
$xpl->dispatch_xpl_message($msg);

is(xPL::Message->new(@{$msg[0]},
                     head => { source => 'test-test.test' })->string,
   'xpl-stat
{
hop=1
source=test-test.test
target=*
}
config.list
{
reconf=username
reconf=password
option=newconf
option=resource
option=host
option=port
option=friend[32]
}
', 'config.list response');

$msg =
  xPL::Message->new(message_type => 'xpl-cmnd',
                    head => { source => 'acme-config.tester' },
                    class => 'config.response',
                    body =>
                    {
                    newconf => 'foo',
                     username => 'user',
                     password => 'pass',
                     bar => 'baz', # should be ignored
                    });

my @args = ();
$xpl->add_event_callback(event => 'config_changed',
                         callback => sub {
 push @args, ['config_changed', @_] });

$xpl->add_event_callback(event => 'config_newconf',
          callback => sub { push @args, ['config_newconf', @_] });
$xpl->add_event_callback(event => 'config_username',
          callback => sub { push @args, ['config_username', @_] });

$xpl->dispatch_xpl_message($msg);

is($xpl->needs_config(), 0, 'needs_config() - all set');

is(scalar @args, 3, 'changes invoked 3 callbacks');
is($args[0]->[0], 'config_newconf', 'newconf - changed');
is_deeply($args[0]->[1],
 {
  new => 'foo',
  old => undef,
  event => 'set',
 }, 'newconf changed - value');

is($args[1]->[0], 'config_username', 'username - set');
is_deeply($args[1]->[1],
 {
  new => 'user',
  old => undef,
  event => 'set',
 }, 'username set - value');

is($args[2]->[0], 'config_changed', 'config changed');
is($args[2]->[1], 'changes', 'config changes hash key');
is_deeply($args[2]->[2],
  [
   { name => 'newconf', new => 'foo', old => undef, event => 'set' },
   { name => 'password', new => 'pass', old => undef, event => 'set' },
   { name => 'username', new => 'user', old => undef, event => 'set' },
  ], 'config_changed - changes');

@args = ();
$xpl->dispatch_xpl_message($msg);
is(scalar @args, 0, 'no changes so no callbacks');

@args = ();
$xpl->remove_event_callback('config_changed');
$msg->extra_field(username => 'bar');
$xpl->dispatch_xpl_message($msg);
is(scalar @args, 1, 'changes involved one callback');
is($args[0]->[0], 'config_username', 'username - changed');
is_deeply($args[0]->[1],
 {
  new => 'bar',
  old => 'user',
  event => 'changed',
 }, 'username set - value');
