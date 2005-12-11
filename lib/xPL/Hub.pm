package xPL::Hub;

# $Id: Hub.pm,v 1.18 2005/12/06 22:17:41 beanz Exp $

=head1 NAME

xPL::Hub - Perl extension for an xPL Hub

=head1 SYNOPSIS

  use xPL::Hub;

  my $xpl = xPL::Hub->new();
  $xpl->add_timer(name => 'tick',
                  timeout => 1,
                  callback => sub { $xpl->tick(@_) },
                  );

  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use POSIX qw/strftime/;
use Socket;
use xPL::Listener;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Listener);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision: 1.18 $/[1];

__PACKAGE__->make_collection(client => [qw/identity ip port sin
                                           interval last/]);

=head2 C<new(%params)>

The constructor creates a new xPL::Hub object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

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

=item port

  The port to listen on.  Default is 3865.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;

  my $self = $pkg->SUPER::new(port => 3865, @_);
  $self->add_xpl_callback(id => "!hub",
                          callback => sub { $self->hub(@_) },
                          targetted => 0);
  $self->add_timer(id => "!clean",
                   timeout => 60,
                   callback => sub {$self->clean_client_list() });
  $self->init_clients();
  return $self;
}

=head2 C<listen_addr()>

Returns the listen port for this source.

=cut

sub listen_addr {
  my $self = shift;
  $self->ouch("called with an argument, but listen_addr is readonly") if (@_);
  return $self->broadcast;
}

=head2 C<hub(%params)>

This method is the xPL message callback that performs the hub actions
of registering clients and forwarding messages.

=cut

sub hub {
  my $self = shift;
  my %p = @_;

  my $msg = $p{message};

  if ($msg->class eq 'hbeat' &&
      ($msg->class_type eq 'app' or $msg->class_type eq 'end') &&
      ($msg->remote_ip eq "127.0.0.1" or $msg->remote_ip eq $self->ip)) {
    my $client = $msg->remote_ip.':'.$msg->port;
    if ($msg->class_type eq 'app') {
      $self->update_client($client, $msg);
    } else {
      $self->remove_client($client);
    }
  }

  foreach my $client ($self->clients) {
    $self->send_aux($self->client_sin($client), $msg);
  }

  return 1;
}

=head2 C<clients()>

This methods returns the list of currently registered clients.  Each
client in this list is identified by a string of the form "ip:port".
This will be unique even if for some reason the identifier ('source')
for the client is not.  The client identifier can be obtained using
the L<client_identity()> method.

=head2 C<client_identity( $client )>

This methods returns the identity ('source') of the given client.

=head2 C<client_info( $client )>

This methods return a string summarising the details of the given
client.

=cut

sub client_info {
  my $self = shift;
  my $client = shift;
  return($self->client_attrib($client, 'identity').
         ' i='.$self->client_interval($client).
         ' l@'.strftime("%H:%M", localtime($self->client_last($client))));
}

=head2 C<update_client( $client, $msg )>

This methods takes a client and a message received and updates the information
stored about that client with the details from the message.

=cut

sub update_client {
  my $self = shift;
  my $client = shift;
  my $msg = shift;
  $self->add_client($client, $msg) unless ($self->exists_client($client));
  $self->client_last($client, time);
  $self->client_interval($client, $msg->interval);
  $self->client_identity($client, $msg->source);
  return 1;
}

=head2 C<exists_client( $client )>

This methods returns true if the given client is registered.

=head2 C<client_last( $client, [ $new_value ] )>

This methods returns the time in seconds since epoch that the hub last
received a hbeat message from the registered client.  If the optional
new value is given the time is updated before it is returned.

=head2 C<client_interval( $client, [ $new_value ] )>

This methods returns the interval (in minutes) as it appeared in the
last hbeat message the hub received from the registered client.  If
the optional new value is given the interval is updated before it is
returned.

=head2 C<client_identity( $client, [ $new_value ] )>

This methods returns the identity as it appeared in the last hbeat
message the hub received from the registered client.  If the optional
new value is given the identity is updated before it is returned.

=head2 C<add_client( $client, $message )>

This method is called by the L<update_client()> method to add clients
that aren't already registered.

=cut

sub add_client {
  my $self = shift;
  my $client = shift;
  my $msg = shift;
  if ($self->exists_client($client)) {
    return $self->ouch("adding already registered client: $client");
  }

  print "Adding client: ",$client, " \"", $msg->source, "\"\n"
    if ($self->verbose);

  my $ip = $msg->remote_ip;
  my $port = $msg->port;
  my $sin = sockaddr_in($port, inet_aton($ip));
  $self->add_item('client',
                  $client,
                  { ip => $ip, port => $port, sin => $sin, });
  return 1;
}

=head2 C<remove_client( $client )>

This method is called to remove a client.  For instance, when a "hbeat.end"
message is received.

=cut

=head2 C<clean_client_list( )>

This method is called periodically to remove clients that have failed
to send hbeat messages recently.

=cut

sub clean_client_list {
  my $self = shift;
  foreach my $client ($self->clients) {
    my $last = $self->client_last($client);
    my $interval = $self->client_interval($client);
    if (time > ($last + 60*(1+($interval*2)))) {
      my $id = $self->client_identity($client);
      print "Removing client: ",$client," \"",$id,"\"\n" if ($self->verbose);
      $self->remove_client($client);
    }
  }
  return 1;
}

1;
__END__

=head1 TODO

There are some 'todo' items for this module:

=over 4

=item Callbacks

The hub should have callbacks for clients coming and going.

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
