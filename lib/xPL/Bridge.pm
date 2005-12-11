package xPL::Bridge;

# $Id$

=head1 NAME

xPL::Bridge - Perl extension for an xPL Bridge

=head1 SYNOPSIS

  use xPL::Bridge;

  # server mode
  my $xpl = xPL::Bridge->new(vendor_id => 'acme',
                             device_id => 'bridge',
                             local_ip => '0.0.0.0');
  $xpl->main_loop();

  # client mode
  my $xpl = xPL::Bridge->new(vendor_id => 'acme',
                             device_id => 'bridge',
                             remote_ip => '10.0.0.2');
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL bridge.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English '-no_match_vars';

my $COLON = q{:};
my $SPACE = q{ };
my $EMPTY = q{};

use Digest::MD5 qw/md5 md5_hex/;
use Socket;
use IO::Socket;
use xPL::Client;

use Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Client);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_collection(peer => [qw/name handle buffer/]);
__PACKAGE__->make_readonly_accessor(qw/timeout bridge_port bridge_mode
                                       remote_ip local_ip/);

=head2 C<new(%params)>

The constructor creates a new xPL::Bridge object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

=item id

  The identity for this source.

=item interface

  The interface to use.  The default is to use the first active
  interface that isn't the loopback interface if there is one, or the
  loopback interface if that is the only one.  (Not yet implemented.)

=item ip

  The IP address to bind to.  This can be used instead of the
  'interface' parameter and will take precedent over the 'interface'
  parameter if they are in conflict.

=item broadcast

  The broadcast address to use.  This is required if the 'ip'
  parameter has been given.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  if(ref $pkg) { $pkg = ref $pkg }

  my $self = $pkg->SUPER::new(@_);

  my %p = @_;
  exists $p{timeout} or $p{timeout} = 120;
  $self->{_timeout} = $p{timeout};

  exists $p{bridge_port} or $p{bridge_port} = 3_866;
  $self->{_bridge_port} = $p{bridge_port};

  $self->init_peers();

  if (exists $p{remote_ip}) {
    $self->setup_client_mode(\%p);
  } else {
    $self->setup_server_mode(\%p);
  }

  $self->add_xpl_callback(id => '!bridge',
                          callback => sub { $self->bridge(@_) },
                          targetted => 0);

  $self->add_timer(id => '!clean-seen-cache',
                   callback => sub { $self->clean_seen_cache(@_); },
                   timeout => 10);

  $self->{_bridge}->{seen} = {};

  return $self;
}

=head2 C<setup_client_mode( \%parameters )>

This method connects to a remote bridge and registers the socket to
wait for incoming messages.

=cut

sub setup_client_mode {
  my $self = shift;
  my $p = shift;
  $self->{_bridge_mode} = 'client';
  $self->{_remote_ip} = $p->{remote_ip};
  my $s = $self->{_bridge}->{sock} =
    IO::Socket::INET->new(PeerAddr => $p->{remote_ip},
                          PeerPort => $p->{bridge_port},
                          Proto => 'tcp',
                          Timeout => $p->{timeout});
  unless ($s) {
    $self->argh("connect to remote peer failed: $!\n");
  }
  $self->add_peer($s,
                  {
                   handle => $s,
                   name => $p->{remote_ip}.$COLON.$p->{bridge_port},
                   buffer => $EMPTY,
                  });
  return 1;
}


=head2 C<setup_server_mode( \%parameters )>

This method bindes to a local port and registers the socket to wait
for incoming connections from client mode bridges.

=cut

sub setup_server_mode {
  my $self = shift;
  my $p = shift;
  $self->{_bridge_mode} = 'server';
  exists $p->{local_ip} or $p->{local_ip} = '0.0.0.0';
  $self->{_local_ip} = $p->{local_ip};
  my $s = $self->{_bridge}->{listen_sock} =
    IO::Socket::INET->new(LocalAddr => $p->{local_ip},
                          LocalPort => $p->{bridge_port},
                          Proto => 'tcp',
                          Timeout => $p->{timeout},
                          Listen => 5,
                          ReuseAddr => 1);
  unless ($s) {
    $self->argh("bind to listen socket failed: $!");
  }
  $self->add_input(handle => $s, callback => sub { $self->sock_accept(@_) });
  return 1;
}

=head2 C<bridge( \%parameters )>

This method is the callback which receives incoming local xPL messages
and forwards them to any remote bridges.  It does not forward any
messages that arrive with a hop count of 9 (or invalid messages with
large hop counts).  It also checks that messages it forwards to remote
bridges have not come from a remote bridge.

=cut

sub bridge {
  my $self = shift;
  my %p = @_;

  my $msg = $p{message};

  print 'Local msg: ', $msg->summary, " ",$msg->hop, "\n" if ($self->verbose);

  my $hop = $msg->hop;
  if ($hop >= 9) {
    warn 'Dropping local msg: ', $msg->summary, "\n";
    return 1;
  }
  $msg->hop($hop+1);

  my $msg_str = $msg->string();
  return 1 if ($self->seen_local($msg_str));

  foreach my $peer ($self->peers) {
    print $peer pack_message($msg_str);
  }

  return 1;
}

=head2 C<peers()>

This method returns the sockets of any remote peers.

=cut

sub peers {
  my $self = shift;
  return map { $self->peer_handle($_) } $self->items('peer');
}

=head2 C<sock_accept( $listen_socket )>

This method is the callback on the listen mode bridge that handles the
incoming connections from client bridges.

=cut

sub sock_accept {
  my $self = shift;
  my $listen_sock = shift;
  my $peer = $listen_sock->accept();
  my $peer_name = $peer->peerhost.$COLON.$peer->peerport;
  print 'New peer: ', $peer_name, "\n" if ($self->verbose);
  $self->add_peer($peer,
                  { handle => $peer, name => $peer_name, buffer => $EMPTY });
  return 1;
}

=head2 C<sock_read( $peer_socket )>

This method is the callback that handles incoming messages from remote
bridges.  Any messages with large or invalid hop counts are dropped.
All other messages are broadcast locally.

=cut

sub sock_read {
  my $self = shift;
  my $peer = shift;
  my $buffer = $self->peer_buffer($peer);
  my $bytes = $peer->sysread($buffer, 1_536, length $buffer);
  unless ($bytes) {
    print 'Connection to ', $peer, " closed\n" if ($self->verbose);
    $peer->close;
    $self->remove_peer($peer);
    if ($self->bridge_mode eq 'client') {
      $self->argh('No one to talk to quitting.');
    }
    return 1;
  }
  while (my $msg_str = unpack_message($buffer)) {
    my $msg;
    eval {
      $msg = xPL::Message->new_from_payload($msg_str);
    };
    if ($EVAL_ERROR) {
      $self->ouch('Invalid message from ',
                  $self->peer_name($peer), $COLON, $SPACE, $EVAL_ERROR);
      return 1;
    }
    $self->mark_seen($msg->string);
    my $hop = $msg->hop;
    if ($hop >= 9) {
      warn 'Dropping msg from ', $self->peer_name($peer), ': ',
        $msg->summary, "\n";
      next;
    }
    $msg->hop($hop+1);

    $self->send($msg);
  }
  $self->peer_buffer($peer, $buffer);
  return 1;
}

=head2 C<add_peer( $peer_socket )>

This method registers a new peer.

=cut

sub add_peer {
  my $self = shift;
  my $sock = shift;
  $self->add_item('peer', $sock, @_);
  $self->add_input(handle => $sock, callback => sub { $self->sock_read(@_) });
  return 1;
}

=head2 C<remove_peer( $peer_socket )>

This method removes a peer from the registered list.

=cut

sub remove_peer {
  my $self = shift;
  my $sock = shift;
  $self->remove_item('peer', $sock);
  $self->remove_input($sock);
  return 1;
}

=head2 C<pack_message( $message_string )>

This function takes an xPL message string and returns an encoded
version for sending to remote bridges.  The encoding is simple using a
4-byte network order length followed by the message string.

=cut

sub pack_message {
  pack 'N/A*', $_[0];
}

=head2 C<unpack_message( $buffer )>

This function removes a message from the start of the buffer and
returns it.  If there isn't enough data in the buffer it returns
undef.

=cut

sub unpack_message {

  # do we have enough data for a length?
  ((length $_[0]) >= 4) or return;

  # read the length
  my $l = unpack 'N', $_[0];

  # is the message complete?
  ((length $_[0]) >= 4+$l) or return;

  # remove length
  substr $_[0], 0, 4, $EMPTY;

  # remove (and return) message
  substr $_[0], 0, $l, $EMPTY;
}

=head2 C<msg_hash( $string )>

This function takes an xPL message string and returns a hash to
represent the message in the cache that prevents looping for remote
messages when they are received back from the local hub.

=cut

sub msg_hash {
  my $string = shift;
  $string =~ s/\nhop=\d+\n/\nhop=9\n/; # chksum must ignore hop count
  return md5_hex($string);
}

=head2 C<mark_seen( $string )>

This method records that an incoming remote message has been seen.

=cut

sub mark_seen {
  my $self = shift;
  my $string = shift;
  my $md5 = msg_hash($string);
  #print STDERR "mark_seen: $md5\n$string\n";
  push @{$self->{_bridge}->{seen}->{$md5}}, time;
  return 1;
}

=head2 C<seen_local( $string )>

This method returns true if the incoming local message has already been
received from a remote bridge.

=cut

sub seen_local {
  my $self = shift;
  my $string = shift;
  my $md5 = msg_hash($string);
  #print STDERR "seen_local: $md5\n$string\n";
  exists $self->{_bridge}->{seen}->{$md5} or return;
  $self->seen_cache_remove($md5);
  return 1;
}

=head2 C<clean_seen_cache()>

This method is a timer callback that periodically clears out any
old keys from the duplicate detection cache.

=cut

sub clean_seen_cache {
  my $self = shift;

  my $cache = $self->{_bridge}->{seen};
  my $time = time - 5;
  foreach my $md5 (keys %$cache) {
    next unless $cache->{$md5}->[0] < $time;
    $self->seen_cache_remove($md5);
  }
  return 1;
}

=head2 C<seen_cache_remove( $hash )>

This method is used to remove an entry from the duplicate detection
cache.

=cut

sub seen_cache_remove {
  my $self = shift;
  my $md5 = shift;
  exists $self->{_bridge}->{seen}->{$md5} or return;
  shift @{$self->{_bridge}->{seen}->{$md5}};
  unless (scalar @{$self->{_bridge}->{seen}->{$md5}}) {
    delete $self->{_bridge}->{seen}->{$md5};
  }
  return 1;
}

1;
__END__

=head1 TODO

There are some 'todo' items for this module:

=over 4

=item Send incoming remote messages to all remote peers except the sender.

=back

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
