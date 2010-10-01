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

use utf8;
use AnyEvent;
use AnyEvent::XMPP::Client;
use AnyEvent::XMPP::IM::Message;

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
  $xpl->add_event_callback(id => $self.'_config_changed',
                           event => 'config_changed',
                           callback => sub {
                             $self->config_changed(@_);
                           });
  unless ($self->config->items_requiring_config) {
    $self->connect();
  }
  return $self;
}

sub config_changed {
  my $self = shift;
  my $config = $self->config;
  return 1 if ($config->items_requiring_config);
  if ($self->{_xmpp}) {
    my %p = @_;
    # TOFIX support reconfiguration
    print STDERR "Reconfigure\n";
    my @changes = @{$p{changes}};
    foreach my $change (@{$p{changes}}) {
      if ($change->{'name'} eq 'friend') {
        my %fm = map { $_ => 1 } split /,/, join ",",
          @{$self->{_friends}}, @{$config->get_item('friend')||[]};
        $self->{_friend_map} = \%fm;
      }
    }
    return 1;
  }
  $self->connect();
}

sub connect {
  my $self = shift;
  print STDERR "Configured!\n";
  my $xpl = $self->{_xpl};
  my $config = $self->config;
  my $host = $config->get_item('host') || $self->{_host};
  my $port = $config->get_item('port') || $self->{_port};
  my $xmpp = $self->{_xmpp} = AnyEvent::XMPP::Client->new(debug => 0);

  $xmpp->add_account($config->get_item('username')||$self->{_user},
                   $config->get_item('password')||$self->{_pass},
                   $host, $port);

  $xmpp->reg_cb(session_ready => sub {
                my ($xmpp, $acc) = @_;
                $xmpp->set_presence('available', 'Bot', 10);
              },
              disconnect => sub {
                my ($xmpp, $acc, $h, $p, $reas) = @_;
                $xpl->info("disconnect ($h:$p): $reas\n");
              },
              error => sub {
                my ($xmpp, $acc, $err) = @_;
                $xpl->argh("ERROR: " . $err->string . "\n");
              },
              message => sub {
                my ($xmpp, $acc, $msg) = @_;
                $self->xmpp_message($xmpp, $msg);
              });
  $xmpp->start;

  $xpl->add_xpl_callback(id => 'im.basic',
                         callback => sub {
                           $self->send_im(@_)
                         },
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'im.basic',
                         });

  my %fm = map { $_ => 1 } split /,/, join ",",
    @{$self->{_friends}}, @{$config->get_item('friend')||[]};
  $self->{_friend_map} = \%fm;
}


sub xmpp_message {
  my ($self, $xmpp, $msg) = @_;
  my $user = $msg->from;
  my $body = $msg->body || '';
  my $from = $user;
  $self->info('Message: ', $from, ': ', $body, "\n") if ($self->verbose);
  $from =~ s!/[^/]+$!!;
  unless (exists $self->{_friend_map}->{$from}) {
    $self->ouch("Non-friend '$from' said '$body'\n");
    return;
  }
  return if ($body =~ /^\s*$/);
  my ($command, $message) = split /\s+/, $body, 2;
  my $reply = $msg->make_reply;
  $command = lc $command;
  if ($command eq 'help') {
    $self->info("Replying to help request\n");
    $reply->add_body("Usage:\n");
  } elsif ($command eq 'xpl') {
    eval { $self->{_xpl}->send_from_string($message); };
    $reply->add_body($@ ? $@ : 'ok');
  } elsif ($command eq 'log') {
    $self->info("Replying to log request\n");
    # TODO: figure out how to do logging
    #$self->{_xpl}->add_xpl_callback(id => $from.'!'.$message,
    #                                callback => sub {
    #                                    $self->log($msg, @_)
    #                                },
    #                                filter => $message);
    $reply->add_body('Sorry, logging is not implemented yet');
  } else {
    $self->{_xpl}->send(message_type => 'xpl-trig',
                        schema => 'im.basic',
                        body =>
                        [
                         body => $body,
                         from => $from,
                        ]);
    return 1;
  }
  $reply->send;
  return 1;
}

sub log {
  my $self = shift;
  my $msg = shift;
  my %p = @_;
  my $reply = $msg->make_reply;
  $reply->add_body($p{message}->summary);
  $reply->send;
  return 1;
}

sub send_im {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  print STDERR $msg->summary, "\n";
  my $to = $msg->field('to');
  exists $self->{_friend_map}->{$to} or return 1;
  my $body = $msg->field('body') or return 1;
  $self->{_xmpp}->send_message($body => $to, undef, 'chat');
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
  foreach my $sid (keys %$result) {
    $result->{$sid} or
      $self->argh("XML::Stream error: ".$self->{_xmpp}->GetErrorCode($sid));
  }
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

Copyright (C) 2008, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
