package xPL::RF::Oregon;

# $Id$

=head1 NAME

xPL::RF::Oregon - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::Oregon;

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

my %types =
  (
   0xfa28 => { part => 'THGR810', len => 80, },
   0xfab8 => { part => 'WTRG800', len => 80, method => 'wtgr800_temphydro', },
   0x1a99 => { part => 'WTRG800', len => 88, method => 'wtgr800_anemometer', },
   0x2a19 => { part => 'RCR800', len => 92, },
   0xda78 => { part => 'UVN800', len => 72, },
   0xea7c => { part => 'UV138', len => 120, method => 'uv138', },
   0xea4c => { part => 'THWR288A', len => 80, },
   0x8aec => { part => 'RTGR328N', len => 104, },
   0x9aec => { part => 'RTGR328N', len => 104, method => 'rtgr328n_datetime', },
   0x1a2d => { part => 'THGR228N/THGR122NX', len => 80, method => 'thgr228n', },
   0x1a3d => { part => 'THGR918', len => 80, },
   0x5a5d => { part => 'BTHR918', len => 88, },
   0x5a6d => { part => 'THGR918N', len => 96, },
   0x3a0d => { part => 'STR918/WGR918', len => 80, },
   0x2a1d => { part => 'RGR126/RGR682/RGR918', len => 80, },
   0x0a4d => { part => 'THR128/THR138', len => 80, method => 'thr128', },
   0xfefe => { part => 'TEST' },
  );

my $DOT = q{.};

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method is called via the main C<xPL::RF> decode loop and it
determines whether the bytes match the format of any supported Oregon
Scientific sensors.  It returns a list reference of containing xPL
messages corresponding to the sensor readings.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $type = ($bytes->[0] << 8) + $bytes->[1];
  if (($type&0xfff) == 0xacc) {
    return $self->rtgr328n_temphydro($parent, $message, $bytes, $bits);
  }
  my $rec = $types{$type};
  unless ($rec) {
    return;
  }
  my $method = $rec->{method};
  unless ($method) {
    warn "Possible message from Oregon part \"",$rec->{part},"\"\n";
    return;
  }
  return $self->$method($parent, $message, $bytes, $bits);
}

=head1 DEVICE METHODS

=head2 C<uv138( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a message from a UV138 sensor.

=cut

sub uv138 {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (checksum1($bytes));
  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = 'uv138.'.$device;
  my @res = ();
  uv($parent, $bytes, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<wtgr800_anemometer( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a wind speed/direction message from a WTGR800 sensor.

=cut

sub wtgr800_anemometer {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (checksum4($bytes));
  my $device = sprintf "%02x", $bytes->[3];
  my $dir = hi_nibble($bytes->[4]) * 22.5;
  my $speed = lo_nibble($bytes->[7]) * 10 + sprintf("%02x",$bytes->[6])/10;
  #print "WTGR800: $device $dir $speed $bat\n";
  my $dev_str = 'wtgr800'.$DOT.$device;
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

=head2 C<wtgr800_temphydro( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity message from a WTGR800 sensor.

=cut

sub wtgr800_temphydro {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (checksum2($bytes));
  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = 'wtgr800'.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  humidity($parent, $bytes, $dev_str, \@res);
  percentage_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<rtgr328n_temphydro( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity message from a RTGR328n sensor.

=cut

sub rtgr328n_temphydro {
  my $self = shift;
  return $self->common_temphydro('rtgr328n', @_);
}

=head2 C<thgr228n( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity message from a THGR228n sensor.

=cut

sub thgr228n {
  my $self = shift;
  return $self->common_temphydro('thgr228n', @_);
}

=head2 C<thr128( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature message from a THR128 sensor.

=cut

sub thr128 {
  my $self = shift;
  return $self->common_temp('thr128', @_);
}

=head2 C<rtgr328n_datetime( $parent, $message, $bytes, $bits )>

This method is called if the device type bytes indicate that the bytes
might contain a date/time message from a RTGR328n sensor.

=cut

sub rtgr328n_datetime {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (checksum3($bytes));
  my $device = sprintf "%02x", $bytes->[3];
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
  my $dev_str = 'rtgr328n.'.$device;
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

  return unless (checksum2($bytes));
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

  return unless (checksum2($bytes));
  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $dev_str, \@res);
  humidity($parent, $bytes, $dev_str, \@res);
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

=head2 C<simple_battery( $parent, $bytes, $device, \@result)>

This method processes a simple low battery reading.  It appends an xPL
message to the result array if the battery is low.

=cut

sub simple_battery {
  my ($parent, $bytes, $dev, $res) = @_;
  my $battery_low = $bytes->[4]&0x4;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-cmnd',
                      class => 'osd.basic',
                      head => { source => $parent->source, },
                      body => {
                               command => 'clear',
                               text => $dev.' has low battery',
                               row => 2,
                              }
                     ) if ($battery_low);
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
                      message_type => 'xpl-cmnd',
                      class => 'osd.basic',
                      head => { source => $parent->source, },
                      body => {
                               command => 'clear',
                               text => $dev.' has low battery ('.$bat.'%)',
                               row => 2,
                              }
                     ) if ($bat < 20);
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

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005, 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
