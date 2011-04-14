package xPL::Dock::APCUPS;

=head1 NAME

xPL::Dock::APCUPS - xPL::Dock plugin for APC UPS daemon monitoring

=head1 SYNOPSIS

  use xPL::Dock qw/APCUPS/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds APC UPS daemon monitoring.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use IO::Socket::INET;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval server/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_interval} = 60;
  $self->{_server} = '127.0.0.1:3551';
  return
    (
     'apcups-verbose+' => \$self->{_verbose},
     'apcups-poll-interval=i' => \$self->{_interval},
     'apcups-server=s' => \$self->{_server},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  # Add a timer to the xPL Client event loop to generate the
  # "apcups.update" messages.  The negative interval causes the timer to
  # trigger immediately rather than waiting for the first interval.
  $xpl->add_timer(id => 'apcups',
                  timeout => -$self->interval,
                  callback => sub { $self->poll(); 1 });

  $self->{_buf} = '';
  $self->{_state} = {};

  return $self;
}

=head2 C<poll( )>

This method is the timer callback that polls the apcups daemon.

=cut

sub poll {
  my $self = shift;
  my $sock = IO::Socket::INET->new($self->server);
  unless ($sock) {
    warn "Failed to contact apcups daemon at ", $self->server, ": $!\n";
    return 1;
  }
  print $sock encode_nis_string("status");
  $self->xpl->add_input(handle => $sock,
                        callback => sub { $self->read(@_); 1; });
  return 1;
}

=head2 C<read( )>

This is the input callback that reads the data from the apcups daemon
and sends appropriate C<sensor.basic> messages and C<ups.basic>
messages.

=cut

sub read {
  my ($self, $sock) = @_;
  my $bytes = $sock->sysread($self->{_buf}, 1024, length($self->{_buf}));
  unless ($bytes) {
    $self->{_buf} = "";
    $self->xpl->remove_input($sock);
    $sock->close;
  }
  while (defined(my $msg = decode_nis_string($self->{_buf}))) {
    next unless ($msg);
    chomp($msg);
    my ($field, $value) = split /\s*:\s*/, $msg, 2;
    my %f =
      (
       LINEV     => [ 'voltage' ],
       LOADPCT   => [ 'generic', 'percent' ],
       BCHARGE   => [ 'battery' ],
       TIMELEFT  => [ 'generic', 's', 60 ],
       OUTPUTV   => [ 'voltage' ],
       ITEMP     => [ 'temp' ],
       BATTV     => [ 'voltage' ],
       LINEFREQ  => [ 'generic', 'hz' ],
       TONBATT   => [ 'generic', 's' ],
      );
    if (exists $f{$field}) {
      my ($type, $units, $multi) = @{$f{$field}};
      my $device = $self->xpl->instance_id.'-'.(lc $field);
      my $old = $self->{_state}->{$device};
      $value =~ s/ .*$//g;
      $value =~ s/^0+\.?(.)/$1/g;
      $value *= $multi if (defined $multi);
      $self->xpl->send_sensor_basic($device, $type, $value, $units);
    } elsif ($field eq 'STATUS') {
      my $state = $value =~ /ONLINE/ ? 'mains' : 'battery';
      $value =~ s/\s+$//;
      my $device = $self->xpl->instance_id.'-'.(lc $field);
      my $old = $self->{_state}->{$device};
      $self->{_state}->{$device} = $state;
      if (!defined $old || $state ne $old) {
        $self->info("$device\[status]=$state ($value)\n");
        if (defined $old) {
          $self->xpl->send(message_type => 'xpl-trig',
                           schema => 'ups.basic',
                           body => [
                                    status => $state,
                                    event => 'on'.$state,
                                   ]
                          );
        }
      }
    }
  }
  return 1;
}

=head2 C<decode_nis_string( $string )>

Decodes a string to be sent by the apcups daemon.

=cut

sub decode_nis_string {
  my $buf_len = length $_[0];
  return unless ($buf_len >= 2);
  my ($c, $l) = unpack "C C", $_[0];
  warn "Invalid string? ", (unpack 'H*', $_[0]), "\n" unless ($c == 0);
  if ($l == 0) {
    substr $_[0], 0, $l+2, '';
    return '';
  }
  return unless ($buf_len >= $l+2);
  my $res = substr $_[0], 0, $l+2, '';
  return substr $res, 2;
}

=head2 C<encode_nis_string( $string )>

Encodes a string to be sent to the apcups daemon.

=cut

sub encode_nis_string {
  return pack "C C a*", 0, length $_[0], $_[0];
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), apcupsd(8)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
