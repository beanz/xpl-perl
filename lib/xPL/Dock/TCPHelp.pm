package xPL::Dock::TCPHelp;

=head1 NAME

xPL::Dock::TCPHelp - xPL::Dock plugin for a TCP helper

=head1 SYNOPSIS

  use xPL::Dock qw/TCPHelp/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds a TCP helper application.  It listens
on TCP port 36850 and waits for messages of the form:

  SHA1HMAC
  VersionString
  TimeInSeconds
  Method
  Lines
  xpl-....
  class.type
  {
  ...
  }

where C<SHA1HMAC> is the Digest::SHA for the remainder of the message.
The message header is omitted since it is supplied by the xPL client.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use IO::Socket::INET;
use Digest::HMAC;
use Digest::SHA;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_verbose} = 0;
  $self->{_address} = '0.0.0.0';
  $self->{_port} = 38650;
  $self->{_wait} = 10;
  return
    (
     'tcphelp-verbose+' => \$self->{_verbose},
     'tcphelp-port=i' => \$self->{_port},
     'tcphelp-address=s' => \$self->{_address},
     'tcphelp-secret=s' => \$self->{_secret},
     'tcphelp-wait=i' => \$self->{_wait},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->required_field($xpl,
                        'secret',
                        'The --tcphelp-secret parameter is required', 1);

  $self->SUPER::init($xpl, @_);
  my $sock = $self->{_listen} =
    IO::Socket::INET->new(Listen => 10, ReuseAddr => 1,
                          LocalPort => $self->{_port},
                          LocalAddr => $self->{_address},
                          Proto => 'tcp')
        or $self->argh('Listen on '.$self->{_address}.':'.$self->{_port}.
                       ' failed: '.$!);
  $self->info('Listening on '.$self->{_address}.':'.$self->{_port}."\n");

  $self->{_clients} = {};

  $xpl->add_input(handle => $sock,
                  callback => \&accept_client,
                  arguments => [ $self, $xpl ]);

  return $self;
}

sub accept_client {
  my $handle = $_[0];
  my ($self, $xpl) = @{$_[1]};
  my $new = $handle->accept();
  $xpl->add_input(handle => $new,
                  callback => \&read_client,
                  arguments => [ $self, $xpl ]);
  $self->{_client}->{$new} =
    {
     fh => $new,
     buf => '',
    };
  $self->info($new." accepted\n");
  return 1;
}

sub read_client {
  my $handle = $_[0];
  my ($self, $xpl) = @{$_[1]};
  my $rec = $self->{_client}->{$handle} or do {
    $self->ouch($handle." not registered\n");
    return $self->close_handle($handle);
  };
  my $bytes = $handle->sysread($rec->{buf}, 2048, length $rec->{buf});
  unless ($bytes) {
    $self->info($handle.": closed\n");
    return $self->close_handle($handle);
  }
  $xpl->info($handle.": read $bytes bytes\n");
  if ($rec->{buf} =~
      s/^(\w+)\r?\n # SHA1HMAC
        (
         (\d+\.\d+)\r?\n # Version
         (\d+)\r?\n # Time in seconds
         (\w+)\r?\n # Method
         (\d+)\r?\n # Lines
         (xpl-(?:cmnd|trig|stat))\r?\n # Message Type
         ([-_a-z0-9]+\.[-_a-z0-9]+)\r?\n # Class
         {\r?\n # Standard xPL Message Body
         ((?:[-_a-z0-9]+=.*?\r?\n)*)
         }\r?\n
        )
       //ix) {
    my ($hmac, $body, $version, $time, $method, $lines,
        $message_type, $class, $body_content) =
          ($1, $2, $3, $4, $5, $6, $7, $8, $9);
    $xpl->info($handle.": message received\n");
    my $digest = Digest::HMAC->new($self->{_secret}, 'Digest::SHA');
    $digest->add($body);
    my $expect = $digest->hexdigest;
    $xpl->info($handle.": HMAC: $hmac\nHMAC? $expect\n");
    unless ($expect eq $hmac) {
      $xpl->ouch($handle.": HMAC invalid\n");
      return $self->close_handle($handle);
    }
    $xpl->info($handle.": HMAC valid\n");
    my $now = time;
    unless ($time > $now-120 && $time < $now+120) {
      $xpl->ouch($handle.": invalid time ($time !~ $now)\n");
      return $self->close_handle($handle);
    }
    $xpl->info($handle.": valid time $time ~= $now\n");
    $body_content =~ s/\r//g;
    eval {
      $xpl->send(message_type => $message_type,
                 class => $class,
                 body_content => $body_content);
    };
    if ($@) {
      $xpl->ouch($handle.": xPL message invalid $@\n");
      return 1;
    }
    unless ($method eq 'POST') {
      return 1;
    }
    my $c = $class;
    $c =~ s/\..*$//;
    $xpl->add_xpl_callback(id => $handle.'!wait',
                           filter =>
                           {
                            class => $c,
                           },
                           callback => \&xpl_response,
                           arguments => [ $self, $xpl, $handle ]);
    $xpl->add_timer(id => $handle.'!timeout', timeout => $self->{_wait},
                    callback => \&give_up,
                    arguments => [ $self, $xpl, $handle ]);

  }
  return 1;
}

sub close_handle {
  my ($self, $handle) = @_;
  my $xpl = $self->{_xpl};
  $xpl->remove_input($handle);
  $xpl->remove_xpl_callback($handle.'!wait') if
    ($xpl->exists_xpl_callback($handle.'!wait'));
  $xpl->remove_timer($handle.'!timeout') if
    ($xpl->exists_timer($handle.'!timeout'));
  $handle->close;
  return 1;
}

sub xpl_response {
  my %p = @_;
  my $msg = $p{message};
  my ($self, $xpl, $handle) = @{$p{arguments}};
  my $string = $msg->string;
  $xpl->info($handle.": sending ".$msg->summary."\n");
  $handle->print($string);
  return 1;
}

sub give_up {
  my %p = @_;
  my ($self, $xpl, $handle) = @{$p{arguments}};
  $xpl->remove_xpl_callback($handle.'!wait') if
    ($xpl->exists_xpl_callback($handle.'!wait'));
  return;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), xosd(1)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
