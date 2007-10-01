package xPL::RF::Visonic;

# $Id$

=head1 NAME

xPL::RF::Visonic - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::Visonic;

=head1 DESCRIPTION

This is a module contains a module for handling the decoding of RF
messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Date::Parse qw/str2time/;
use xPL::Message;
use xPL::Utils qw/:all/;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision$/[1];

my %bits =
  (
   36 => 'powercode',
   66 => 'codesecure',
  );

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method is called via the main C<xPL::RF> decode loop and it
determines whether the bytes match the format of any supported Visonic
devices.  It returns a list reference of containing xPL messages
corresponding to the sensor readings.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $method = $bits{$bits};
  unless ($method) {
    return;
  }
  return $self->$method($parent, $message, $bytes, $bits);
}

sub codesecure {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  # parity check?

  my $code =
    sprintf "%02x%02x%02x%02x",
      $bytes->[0], $bytes->[1], $bytes->[2], $bytes->[3];

  my $device =
    sprintf "%02x%02x%02x%x",
      $bytes->[4], $bytes->[5], $bytes->[6], hi_nibble($bytes->[7]);
  my $event =
    { 0x1 => "light",
      0x2 => "arm-away",
      0x4 => "disarm",
      0x8 => "arm-home",
    }->{lo_nibble($bytes->[7])};
  my $repeat = $bytes->[8]&0x4;
  my $low_bat = $bytes->[8]&0x8;

  my %args =
    (
     message_type => 'xpl-trig',
     class => 'x10.security',
     head => { source => $parent->source, },
     body => {
              command => $event,
              device  => $device,
              type => 'codesecure',
             }
    );
  $args{'body'}->{'low-battery'} = 'true' if ($low_bat);
  $args{'body'}->{'repeat'} = 'true' if ($repeat);
  return [ xPL::Message->new(%args) ];
}

sub powercode {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $parity;
  foreach (0 .. 3) {
    $parity ^= hi_nibble($bytes->[$_]);
    $parity ^= lo_nibble($bytes->[$_]);
  }
  unless ($parity == hi_nibble($bytes->[4])) {
    # parity error
    return;
  }

  my $device = sprintf("%02x%02x%02x",
                       $bytes->[0], $bytes->[1], $bytes->[2]);
  $device .= 's' unless ($bytes->[3] & 0x4); # suffix s for secondary contact
  my $restore = $bytes->[3] & 0x8;
  my $event   = $bytes->[3] & 0x10;
  my $low_bat = $bytes->[3] & 0x20;
  my $alert   = $bytes->[3] & 0x40;
  my $tamper  = $bytes->[3] & 0x80;

  # I assume $event is to distinguish whether it's a new event of just a
  # heartbeat message - perhaps we should send xpl-stat if it is just a
  # heartbeat

  my @res;
  my %args =
    (
     message_type => 'xpl-trig',
     class => 'security.zone',
     head => { source => $parent->source, },
     body => {
              event => 'alert',
              zone  => 'powercode.'.$device,
              state => $alert ? 'true' : 'false',
             }
    );
  $args{'body'}->{'tamper'} = 'true' if ($tamper);
  $args{'body'}->{'low-battery'} = 'true' if ($low_bat);
  $args{'body'}->{'restore'} = 'true' if ($restore);
  push @res, xPL::Message->new(%args);
#x10.security
#{
#command=alert|normal|motion|light|dark|arm-home|arm-away|disarm|panic|lights-on
#|lights-off
#device=<device id>
#[type=sh624|kr10|ds10|ds90|ms10|ms20|ms90|dm10|sd90|...]
#[tamper=true|false]
#[low-battery=true|false]
#[delay=min|max]
#}
  %args =
    (
     message_type => 'xpl-trig',
     class => 'x10.security',
     head => { source => $parent->source, },
     body => {
              command => $alert ? 'alert' : 'normal',
              device  => $device,
              type => 'powercode',
             }
    );
  $args{'body'}->{'tamper'} = 'true' if ($tamper);
  $args{'body'}->{'low-battery'} = 'true' if ($low_bat);
  $args{'body'}->{'event'} = $event ? 'event' : 'alive';
  $args{'body'}->{'restore'} = 'true' if ($restore);
  push @res, xPL::Message->new(%args);
  return \@res;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 THANKS

Special thanks to RFXCOM, L<http://www.rfxcom.com/>, for their
excellent documentation and for giving me permission to use it to help
me write this code.  I own a number of their products and highly
recommend them.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
