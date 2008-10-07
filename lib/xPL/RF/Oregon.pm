package xPL::RF::Oregon;

# $Id$

=head1 NAME

xPL::RF::Oregon - Perl extension for decoding Oregon Scientific RF messages

=head1 SYNOPSIS

  use xPL::RF::Oregon;

=head1 DESCRIPTION

This is a module for decoding RF messages from Oregon Scientific
sensor devices.

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

my %types =
  (
   0xfa28 => { part => 'THGR810', len => 80,
               checksum => \&checksum2, method => 'common_temphydro', },
   0xfab8 => { part => 'WTGR800',
               len => 80,  checksum => \&checksum2,
               method => 'alt_temphydro', },
   0x1a99 => { part => 'WTGR800',
               len => 88, checksum => \&checksum4,
               method => 'wtgr800_anemometer', },
   0x2a19 => { part => 'RCR800', len => 92, },
   0xda78 => { part => 'UVN800', len => 72, },
   0xea7c => { part => 'UV138',
               len => 120, checksum => \&checksum1, method => 'uv138', },
   0xea4c => { part => 'THWR288A', len => 80,
               checksum => \&checksum1, method => 'common_temp', },
   0x8aec => { part => 'RTGR328N', len => 104, },
   0x9aec => { part => 'RTGR328N',
               len => 104, checksum => \&checksum3,
               method => 'rtgr328n_datetime', },
   0x9aea => { part => 'RTGR328N',
               len => 104, checksum => \&checksum3,
               method => 'rtgr328n_datetime', },
   0x1a2d => { part => 'THGR228N',
               len => 80, checksum => \&checksum2,
               method => 'common_temphydro', },
   0x1a3d => { part => 'THGR918', len => 80,
               checksum => \&checksum2, method => 'common_temphydro', },
   0x5a5d => { part => 'BTHR918', len => 88,
               checksum => \&checksum5, method => 'common_temphydrobaro', },
   0x5a6d => { part => 'BTHR918N', len => 96,
               checksum => \&checksum5, method => 'alt_temphydrobaro', },
   0x3a0d => { part => 'WGR918',  checksum => \&checksum4,
               len => { map { $_ => 1 } (80,88) },
               method => 'wgr918_anemometer', },
   0x2a1d => { part => 'RGR918', len => 84,
               checksum => \&checksum6, method => 'common_rain', },
   0x0a4d => { part => 'THR128', len => 80,
               checksum => \&checksum2, method => 'common_temp', },
   #0x0a4d => { part => 'THR138', len => 80, method => 'common_temp', },

   0xca2c => { part => 'THGR328N',
               len => 80, checksum => \&checksum2,
               method => 'common_temphydro', },

   # masked
   0x0acc => { part => 'RTGR328N', len => 80, checksum => \&checksum2,
               method => 'common_temphydro', },

   # for testing
   0xfefe => { part => 'TEST' },
  );

my $DOT = q{.};

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method is called via the main C<xPL::RF> decode loop and it
determines whether the bytes match the format of any supported Oregon
Scientific sensors.  It returns a list reference of containing xPL
messages corresponding to the sensor readings or undef if the message
is not recognized.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (scalar @$bytes >= 2);

  my $type = ($bytes->[0] << 8) + $bytes->[1];
  my $rec = $types{$type} || $types{$type&0xfff};
  unless ($rec) {
    return;
  }
  my $len = $rec->{len};
  if ($len) {
    if (ref $len) {
      if (!$len->{$bits}) {
        warn "Unexpected length message from possible Oregon part \"",
          $rec->{part},"\" with length $bits not ",
            (join '/',sort keys %{$len}),"\n";
        return;
      }
    } elsif ($bits != $len) {
      warn "Unexpected length message from possible Oregon part \"",
        $rec->{part},"\" with length $bits not $len\n";
      return;
    }
  }

  my $checksum = $rec->{checksum};
  if ($checksum && !$checksum->($bytes)) {
    return;
  }

  my $method = $rec->{method};
  unless ($method) {
    warn "Possible message from Oregon part \"",$rec->{part},"\"\n";
    return;
  }
  return $self->$method(lc $rec->{part}, $parent, $message, $bytes, $bits);
}

=head1 DEVICE METHODS

=head2 C<uv138( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a message from a UV138 sensor.

=cut

sub uv138 {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  uv($parent, $bytes, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<wgr918_anemometer( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a wind speed/direction message from a WGR918 sensor.

=cut

sub wgr918_anemometer {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my $dir = sprintf("%02x",$bytes->[5])*10 + hi_nibble($bytes->[4]);
  my $speed = lo_nibble($bytes->[7]) * 10 + sprintf("%02x",$bytes->[6])/10;
  my $avspeed = sprintf("%02x",$bytes->[8]) + hi_nibble($bytes->[7]) / 10;
  #print "WGR918: $device $dir $speed\n";
  my @res = ();
  push @res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'speed',
                               current => $speed,
                               average => $avspeed,
                               units => 'mps',
                              }
                     ),
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'direction',
                               current => $dir,
                               units => 'degrees',
                              }
                     );
  percentage_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<wtgr800_anemometer( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a wind speed/direction message from a WTGR800 sensor.

=cut

sub wtgr800_anemometer {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my $dir = hi_nibble($bytes->[4]) * 22.5;
  my $speed = lo_nibble($bytes->[7]) * 10 + sprintf("%02x",$bytes->[6])/10;
  #print "WTGR800: $device $dir $speed\n";
  my @res = ();
  push @res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'speed',
                               current => $speed,
                               units => 'mps',
                              }
                     ),
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'direction',
                               current => $dir,
                              }
                     );
  percentage_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<alt_temphydro( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity message from a WTGR800 sensor.

=cut

sub alt_temphydro {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  humidity($parent, $bytes, $dev_str, \@res);
  percentage_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<alt_temphydrobaro( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity/baro message from a BTHR918N sensor.

=cut

sub alt_temphydrobaro {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  humidity($parent, $bytes, $dev_str, \@res);
  pressure($parent, $bytes, $dev_str, \@res, hi_nibble($bytes->[9]), 856);
  percentage_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<rtgr328n_datetime( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a date/time message from a RTGR328n sensor.

=cut

sub rtgr328n_datetime {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my $time =
    (
     lo_nibble($bytes->[7]).hi_nibble($bytes->[6]).
     lo_nibble($bytes->[6]).hi_nibble($bytes->[5]).
     lo_nibble($bytes->[5]).hi_nibble($bytes->[4])
    );
  my $day =
    [ 'Mon', 'Tues', 'Wednes',
      'Thur', 'Fri', 'Satur', 'Sun' ]->[($bytes->[9]&0x7)-1];
  my $date =
    2000+(lo_nibble($bytes->[10]).hi_nibble($bytes->[9])).
      sprintf("%02d",hi_nibble($bytes->[8])).
        lo_nibble($bytes->[8]).hi_nibble($bytes->[7]);

  #print STDERR "datetime: $date $time $day\n";
  my @res = ();
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'datetime.basic',
                            head => { source => $parent->source, },
                            body => {
                                     datetime => $date.$time,
                                     'date' => $date,
                                     'time' => $time,
                                     day => $day.'day',
                                     device => $dev_str,
                                    }
                           )];
}

=head2 C<common_temp( $type, $parent, $message, $bytes, $bits )>

This method is a generic device method for devices that report
temperature in a particular manner.

=cut

sub common_temp {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<common_temphydro( $type, $parent, $message, $bytes, $bits )>

This method is a generic device method for devices that report
temperature and humidity in a particular manner.

=cut

sub common_temphydro {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  humidity($parent, $bytes, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<common_temphydrobaro( $type, $parent, $message, $bytes, $bits )>

This method is a generic device method for devices that report
temperature, humidity and barometric pressure in a particular manner.

=cut

sub common_temphydrobaro {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  humidity($parent, $bytes, $dev_str, \@res);
  pressure($parent, $bytes, $dev_str, \@res, lo_nibble($bytes->[9]));
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<common_rain( $type, $parent, $message, $bytes, $bits )>

This method is a generic device method for devices that report
temperature, humidity and barometric pressure in a particular manner.

=cut

sub common_rain {
  my $self = shift;
  my $type = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  my $rain = sprintf("%02x",$bytes->[5])*10 + hi_nibble($bytes->[4]);
  my $train = lo_nibble($bytes->[8])*1000 +
    sprintf("%02x", $bytes->[7])*10 + hi_nibble($bytes->[6]);
  my $flip = lo_nibble($bytes->[6]);
  #print STDERR "$dev_str rain = $rain, total = $train, flip = $flip\n";
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'speed',
                               current => $rain,
                               units => 'mm/h',
                              }
                     );
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'distance',
                               current => $train,
                               units => 'mm',
                              }
                     );
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev_str,
                               type => 'count',
                               current => $flip,
                               units => 'flips',
                              }
                     );
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head1 CHECKSUM METHODS

=head2 C<checksum1( $bytes )>

This method is a byte checksum of all nibbles of the first 6 bytes,
the low nibble of the 7th byte, minus 10 which should equal the byte
consisting of a high nibble taken from the low nibble of the 8th byte
plus the high nibble from the 7th byte.

=cut

sub checksum1 {
  my $c = hi_nibble($_[0]->[6]) + (lo_nibble($_[0]->[7])<<4);
  my $s = ( ( nibble_sum(6, $_[0]) + lo_nibble($_[0]->[6]) - 0xa) & 0xff);
  $s == $c;
}

=head2 C<checksum2( $bytes )>

This method is a byte checksum of all nibbles of the first 8 bytes
minus 10, which should equal the 9th byte.

=cut

sub checksum2 {
  $_[0]->[8] == ((nibble_sum(8,$_[0]) - 0xa) & 0xff);
}

=head2 C<checksum3( $bytes )>

This method is a byte checksum of all nibbles of the first 11 bytes
minus 10, which should equal the 12th byte.

=cut

sub checksum3 {
  $_[0]->[11] == ((nibble_sum(11,$_[0]) - 0xa) & 0xff);
}

=head2 C<checksum4( $bytes )>

This method is a byte checksum of all nibbles of the first 9 bytes
minus 10, which should equal the 10th byte.

=cut

sub checksum4 {
  $_[0]->[9] == ((nibble_sum(9,$_[0]) - 0xa) & 0xff);
}

=head2 C<checksum5( $bytes )>

This method is a byte checksum of all nibbles of the first 10 bytes
minus 10, which should equal the 11th byte.

=cut

sub checksum5 {
  $_[0]->[10] == ((nibble_sum(10,$_[0]) - 0xa) & 0xff);
}

=head2 C<checksum6( $bytes )>

This method is a byte checksum of all nibbles of the first 10 bytes
minus 10, which should equal the 11th byte.

=cut

sub checksum6 {
  hi_nibble($_[0]->[8])+(lo_nibble($_[0]->[9])<<4) ==
    ((nibble_sum(8,$_[0]) - 0xa) & 0xff);
}

my @uv_str =
  (
   qw/low low low/, # 0 - 2
   qw/medium medium medium/, # 3 - 5
   qw/high high/, # 6 - 7
   'very high', 'very high', 'very high', # 8 - 10
  );

=head1 UTILITY METHODS

=head2 C<uv_string( $uv_index )>

This method takes the UV Index and returns a suitable string.

=cut

sub uv_string {
  $uv_str[$_[0]] || 'dangerous';
}

=head1 SENSOR READING METHODS

=head2 C<uv( $parent, $bytes, $device, \@result)>

This method processes a UV Index reading.  It appends an xPL message
to the result array.

=cut

sub uv {
  my ($parent, $bytes, $dev, $res) = @_;
  my $uv =  lo_nibble($bytes->[5])*10 + hi_nibble($bytes->[4]);
  my $risk = uv_string($uv);
  #printf STDERR "%s uv=%d risk=%s\n", $dev, $uv, $risk;
  push @$res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev,
                               type => 'uv',
                               current => $uv,
                               risk => $risk,
                              }
                     );
  1;
}

=head2 C<temperature( $parent, $bytes, $device, \@result)>

This method processes a temperature reading.  It appends an xPL message
to the result array.

=cut

sub temperature {
  my ($parent, $bytes, $dev, $res) = @_;
  my $temp =
    (($bytes->[6]&0x8) ? -1 : 1) *
      (hi_nibble($bytes->[5])*10 + lo_nibble($bytes->[5]) +
       hi_nibble($bytes->[4])/10);
  #printf STDERR "%s temp=%.1f\n", $dev, $temp;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev,
                               type => 'temp',
                               current => $temp,
                              }
                     );
  1;
}

=head2 C<humidity( $parent, $bytes, $device, \@result)>

This method processes a humidity reading.  It appends an xPL message
to the result array.

=cut

sub humidity {
  my ($parent, $bytes, $dev, $res) = @_;
  my $hum = lo_nibble($bytes->[7])*10 + hi_nibble($bytes->[6]);
  my $hum_str = ['normal', 'comfortable', 'dry', 'wet']->[$bytes->[7]>>6];
  #printf STDERR "%s hum=%d%% %s\n", $dev, $hum, $hum_str;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev,
                               type => 'humidity',
                               current => $hum,
                               string => $hum_str,
                              }
                     );
  1;
}

=head2 C<pressure( $parent, $bytes, $device, \@result, $forecast_nibble,
                   $offset )>

This method processes a pressure reading.  It appends an xPL message
to the result array.

=cut

sub pressure {
  my ($parent, $bytes, $dev, $res, $forecast_nibble, $offset) = @_;
  $offset = 795 unless ($offset);
  my $hpa = $bytes->[8]+$offset;
  my $forecast = { 0xc => 'sunny',
                   0x6 => 'partly',
                   0x2 => 'cloudy',
                   0x3 => 'rain',
                 }->{$forecast_nibble} || 'unknown';
  #printf STDERR "%s baro: %d %s\n", $dev, $hpa, $forecast;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev,
                               type => 'pressure',
                               current => $hpa,
                               units => 'hPa',
                               forecast => $forecast,
                              }
                     );
  1;
}

=head2 C<simple_battery( $parent, $bytes, $device, \@result)>

This method processes a simple low battery reading.  It appends an xPL
message to the result array if the battery is low.

=cut

sub simple_battery {
  my ($parent, $bytes, $dev, $res) = @_;
  my $battery_low = $bytes->[4]&0x4;
  my $bat = $battery_low ? 10 : 90;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev,
                               type => 'battery',
                               current => $bat,
                               units => '%',
                              }
                     );
  $battery_low;
}

=head2 C<percentage_battery( $parent, $bytes, $device, \@result)>

This method processes a battery percentage charge reading.  It appends
an xPL message to the result array if the battery is low.

=cut

sub percentage_battery {
  my ($parent, $bytes, $dev, $res) = @_;
  my $bat = 100-10*lo_nibble($bytes->[4]);
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => {
                               device => $dev,
                               type => 'battery',
                               current => $bat,
                               units => '%',
                              }
                     );
  $bat < 20;
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

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
