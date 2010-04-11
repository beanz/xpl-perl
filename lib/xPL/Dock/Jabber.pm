package xPL::Dock::Jabber;

=head1 NAME

xPL::Dock::Jabber - xPL::Dock plugin for Jabber chat interface

=head1 SYNOPSIS

  use xPL::Dock qw/Jabber/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds Jabber chat interface.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use Net::XMPP;
{
  # http://blogs.perl.org/users/marco_fontani/2010/03/google-talk-with-perl.html
  # monkey-patch XML::Stream to support the google-added JID
  package XML::Stream;
  no warnings 'redefine';
  sub SASLAuth {
    my $self = shift;
    my $sid  = shift;
    my $first_step =
      $self->{SIDS}->{$sid}->{sasl}->{client}->client_start();
    my $first_step64 = MIME::Base64::encode_base64($first_step,"");
    $self->Send( $sid,
                 "<auth xmlns='" . &ConstXMLNS('xmpp-sasl') .
                 "' mechanism='" .
                 $self->{SIDS}->{$sid}->{sasl}->{client}->mechanism() .
                 "' " .  q{xmlns:ga='http://www.google.com/talk/protocol/auth'
            ga:client-uses-full-bind-result='true'} . # JID
                 ">".$first_step64."</auth>");
  }
}

use POSIX qw/strftime/;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/host port
                                                    user pass resource/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_host} = 'jabber.org';
  $self->{_port} = 5222;
  $self->{_resource} = 'House';
  $self->{_friends} = [];
  return
    (
     'jabber-verbose+' => \$self->{_verbose},
     'jabber-port=i' => \$self->{_port},
     'jabber-host=s' => \$self->{_host},
     'jabber-username=s' => \$self->{_user},
     'jabber-password=s' => \$self->{_pass},
     'jabber-resource=s' => \$self->{_resource},
     'jabber-friend=s@' => $self->{_friends},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  my $xmpp = $self->{_xmpp} = Net::XMPP::Client->new( debuglevelxx => 100 );
  my %con_args =
    (
     hostname => $self->{_host},
     port => $self->{_port},
     connectiontype => 'tcpip',
     tls => 1,
    );
  if ($self->{_host} =~ /google\.com$/) {
    print STDERR "Setting componentname and tls\n";
    $con_args{componentname} = 'gmail.com';
    $con_args{tls} = 1;
    $xmpp->{SERVER}->{componentname} = 'gmail.com';
  }
  $xmpp->Connect(%con_args)
    or $self->argh("Failed to connect to ".
                   $self->{_host}.':'.$self->{_port}.": $!\n");
  $self->info("Connected to jabber server\n");
  $xmpp->SetCallBacks(presence => sub { $self->jabber_presence(@_); },
                      message => sub { $self->jabber_message(@_); },
                     );

  my $stream = $xmpp->{STREAM};
  $self->info("STREAM: $stream\n");
  my $sid = $xmpp->{SESSION}->{id};
  $self->info("SID: $sid\n");

  my ($type, $message) =
    $xmpp->AuthSend(username => $self->{_user},
                    password => $self->{_pass},
                    resource => $self->{_resource});

  unless ($type eq 'ok') {
    $self->argh("Failed to authenticate - $type: $message\n");
  }
  $self->info("Authenticated with jabber server\n");

  $xmpp->RosterGet();
  $self->info("Roster requested\n");

  $xmpp->PresenceSend();
  $self->info("Presence sent\n");

  # try to ensure the connection is set up
  my $result = $xmpp->Process(1.04);

  $sid = $xmpp->{SESSION}->{id};
  $self->info("SID: $sid\n");

  foreach (keys %{$stream->{SIDS}}) {
    print "SIDS: ", $_, "\n";
  }
  my $jsock = $self->{_jsock} = $stream->{SIDS}->{$sid}->{sock};
  $self->argh("Jabber connection failed\n") unless ($jsock);
  undef $self->{_select};
  $xpl->add_input(handle => $jsock, callback => sub { $self->jabber_read() });

  $self->{_xpl}->add_xpl_callback(id => 'im.basic',
                                  callback => sub {
                                      $self->send_im(@_)
                                  },
                                  filter => {
                                             message_type => 'xpl-cmnd',
                                             class => 'im',
                                             class_type => 'basic',
                                            });

  my %fm = map { $_ => 1 } split /,/, join ",", @{$self->{_friends}};
  $self->{_friend_map} = \%fm;

  return $self;
}

sub jabber_message {
  my $self = shift;
  my ($sid, $obj) = @_;
  my $from = $obj->GetFrom();
  my $type = $obj->GetType();
  my $subj = $obj->GetSubject();
  my $body = $obj->GetBody();
  print STDERR "Message: ", $from, " ! ", $type, " ! ",
                   $subj, " ! ", $body, " !\n" if ($self->verbose);
  return unless ($type eq 'chat');
  return unless ($body);
  $from =~ s!/[^/]+!!;
  return unless (exists $self->{_friend_map}->{$from});
  my ($command, $message) = split /\s+/, $body, 2;
  if ($command eq 'help') {
    $self->info("Replying to help request\n");
    $self->{_xmpp}->Send($obj->Reply(body => "Usage:\n"));
  } elsif ($command eq 'xpl') {
    eval { $self->{_xpl}->send_from_string($message); };
    return 1;
  } elsif ($command eq 'log') {
    $self->info("Replying to log request\n");
    # TODO: figure out how to do logging
    #$self->{_xpl}->add_xpl_callback(id => $from.'!'.$message,
    #                                callback => sub {
    #                                    $self->log($from, $obj, @_)
    #                                },
    #                                filter => $message);
    return 1;
  } else {
    $self->{_xpl}->send(message_type => 'xpl-trig',
                        class => 'im.basic',
                        body =>
                        {
                         body => $body,
                         from => $from,
                        });
  }

  return 1;
}

sub log {
  my $self = shift;
  my $from = shift;
  my $obj = shift;
  my %p = @_;
  my $msg = $p{message};
  $self->{_xmpp}->Send($obj->Reply(body => $msg->summary));
  return 1;
}

sub send_im {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  print STDERR $msg->summary, "\n";
  my $to = $msg->to();
  exists $self->{_friend_map}->{$to} or return 1;
  my $body = $msg->body() or return 1;
  $self->{_xmpp}->MessageSend(to => $to, body => $body);
  return 1;
}

sub jabber_presence {
  my $self = shift;
  my ($sid, $obj) = @_;
  print STDERR "Presence: ", $obj->GetFrom(), " ! ",
    $obj->GetType, " ! ", $obj->GetShow, " !\n" if ($self->verbose);
  return 1;
}

sub jabber_read {
  my $self = shift;
  my $result = $self->{_xmpp}->Process(0.01);
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), Net::XMPP(3)

Project website: http://www.xpl-perl.org.uk/

Jabber website: http://www.jabber.org/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
