package xPL::RF::RFXSensor;

# $Id$

=head1 NAME

xPL::RF::RFXSensor - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::RFXSensor;

=head1 DESCRIPTION

This is a module contains a module for handling the decoding of RF
messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
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

my %info =
  (
   0x01 => "sensor addresses incremented",
   0x02 => "battery low detected",
   0x03 => "conversion not ready",
  );

my %error =
  (
   0x81 => "no 1-wire device connected",
   0x82 => "1-wire ROM CRC error",
   0x83 => "1-wire device connected is not a DS18B20 or DS2438",
   0x84 => "no end of read signal received from 1-wire device",
   0x85 => "1-wire scratchpad CRC error",
   0x86 => "temperature conversion not ready in time",
   0x87 => "A/D conversion not ready in time",
  );

=head2 C<parse( $parent, $message, $bytes, $bits )>

TODO: POD

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 32 or return;
  if ($bytes->[0] == 0x52 && $bytes->[1] == 0x46 &&
      ( $bytes->[2] == 0x58 || $bytes->[2] == 0x32 || $bytes->[2] == 0x33 ) ) {
    return $self->parse_init($parent, $message, $bytes, $bits);
  }
  (($bytes->[0]^0xf0) == $bytes->[1]) or return;
  ((nibble_sum(3.5, $bytes)&0xf)^0xf) == lo_nibble($bytes->[3]) or return;
  my $device = sprintf("rfxsensor%02x%02x", $bytes->[0], $bytes->[1]);
  my $base = sprintf("%02x%02x", $bytes->[0]&0xfc, $bytes->[1]&0xfc);
  my $cache = $parent->unstash('rfxsensor_cache');
  unless ($cache) {
    $cache = $parent->stash('rfxsensor_cache', {});
  }
  my $supply_voltage = $cache->{$base}->{supply};
  my $last_temp = $cache->{$base}->{temp};
  my $flag = $bytes->[3]&0x10;
  if ($flag) {
    if (exists $info{$bytes->[2]}) {
      warn "RFXSensor info $device: ".$info{$bytes->[2]}."\n";
    } elsif (exists $error{$bytes->[2]}) {
      warn "RFXSensor error $device: ".$error{$bytes->[2]}."\n";
    } else {
      warn sprintf "RFXSensor unknown status messages: %02x\n", $bytes->[2];
    }
    return;
  } else {
    my $type = ($bytes->[0]&0x3);
    if ($type == 0) {
      # temp
      my $temp = $bytes->[2] + (($bytes->[3]&0xe0)/0x100);
      if ($temp > 150) {
        $temp = -1*(256-$temp);
      }
      $cache->{$base}->{temp} = $temp;
      return [xPL::Message->new(
                                message_type => 'xpl-trig',
                                class => 'sensor.basic',
                                head => { source => $parent->source, },
                                body => {
                                         device => $device,
                                         type => 'temp',
                                         current => $temp,
                                         base_device => $base,
                                        }
                               )];
    } elsif ($type == 1) {
      my $v = ( ($bytes->[2]<<3) + ($bytes->[3]>>5) ) / 100;
      my @res = ();
      push @res,
        xPL::Message->new(
                          message_type => 'xpl-trig',
                          class => 'sensor.basic',
                          head => { source => $parent->source, },
                          body => {
                                   device => $device,
                                   type => 'voltage',
                                   current => $v,
                                   base_device => $base,
                                  }
                         );
      unless (defined $supply_voltage) {
        warn "Don't have supply voltage for $device/$base yet\n";
        return \@res;
      }
      # See http://archives.sensorsmag.com/articles/0800/62/main.shtml
      my $hum = sprintf "%.2f", (($v/$supply_voltage) - 0.16)/0.0062;
      #print STDERR "Sensor Hum: $hum\n";
      if (defined $last_temp) {
        #print STDERR "Last temp: $last_temp\n";
        $hum = sprintf "%.2f", $hum / (1.0546 - 0.00216*$last_temp);
        #print STDERR "True Hum: $hum\n";
      } else {
        warn "Don't have temperature for $device/$base yet - assuming 25'C\n";
      }
      push @res,
                xPL::Message->new(
                          message_type => 'xpl-trig',
                          class => 'sensor.basic',
                          head => { source => $parent->source, },
                          body => {
                                   device => $device,
                                   type => 'humidity',
                                   current => $hum,
                                   base_device => $base,
                                  }
                         );
      return \@res;
    } elsif ($type == 2) {
      my $v = ( ($bytes->[2]<<3) + ($bytes->[3]>>5) ) / 100;
      $cache->{$base}->{supply} = $v;
      return [xPL::Message->new(
                                message_type => 'xpl-trig',
                                class => 'sensor.basic',
                                head => { source => $parent->source, },
                                body => {
                                         device => $device,
                                         type => 'voltage',
                                         current => $v,
                                         base_device => $base,
                                        }
                               )];
    } else {
      warn "Unsupported RFXSensor: type=$type\n";
      # not implemented yet
    }
  }
  return;
}

sub parse_init {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  warn sprintf "RFXSensor %s, version %02x, initialized\n",
    { 0x58 => 'Type-1', 0x32 => 'Type-2', 0x33 => 'Type-3' }->{$bytes->[2]},
      $bytes->[3];
  return [];
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
