package xPL::RF;

# $Id: RF.pm 192 2007-03-03 19:05:56Z beanz $

=head1 NAME

xPL::RF - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF;

=head1 DESCRIPTION

This is a module contains a module for handling the decoding of RF
messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Time::HiRes;
use xPL::Message;
use Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(hex_dump) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision: 192 $/[1];

=head2 C<new(%parameter_hash)>

The constructor creates a new xPL::RF object.  The constructor takes a
parameter hash as arguments.  Valid parameters in the hash are:

=over 4

=item duplicate_timeout

  The amount of time that a message is considered a duplicate if it
  is identical to an earlier message.  The default is .5 seconds.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  my $self = {};
  bless $self, $pkg;
  $self->{_verbose} = 1;
  $self->{_source} = $p{source} or
    die "$pkg->new: requires 'source' parameter\n";
  $self->{_default_x10_level} = 10;
  $self->{_duplicate_timeout} = $p{duplicate_timeout} || .5;
  $self->{_cache} = {};
  return $self;
}

=head2 C<process_variable_length( $buf )>

This function takes a message buffer containing an RFXCom variable
length mode message.  It parses it and dispatches it for processing to
one of the other functions depending on the type.

It undef if the buffer is invalid or a hash reference containing the
following keys:

=over 4

=item C<length>

The length of the processed message on success, 0 if more
data is needed.

=item C<messages>

An array references containing any xPL messages created from the
decoded buffer.

=back

=cut

sub process_variable_length {
  my $self = shift;
  my $buf = shift;
  my ($hdr_byte, @bytes) = unpack("C*", $buf);
  if ($hdr_byte == 0x2c || $hdr_byte == 0x4d) {
    # skip responses
    return undef;
  }

  # TODO: master/slave ?
  my $length_bits = $hdr_byte & 0x7f;
  return { length => 1, messages => [] } if ($length_bits == 0);
  unless ($length_bits == 0x29 || $length_bits%8 == 0) {
    # not a length in bits
    return undef;
  }
  my $length = $length_bits / 8;
  if (scalar @bytes < $length) {
    # not enough data in buffer
    return { length => 0, messages => [] };
  }
  if ($length != int($length)) {
    # not a whole number of bytes so we must round it up
    $length = int($length)+1;
  }
  my $res = { length => $length+1, messages => [] };
  my $msg = substr($buf, 1, $length); # message from buffer
  return $res if ($self->is_duplicate($msg));
  if ($length == 4) {
    #process 32bit
    $res->{messages} = $self->process_32bit($msg);
  } elsif ($length == 6) {
    #process 48bit
    $res->{messages} = $self->process_48bit($msg);
  } elsif ($length == 15) {
    #process 120bit
    $res->{messages} = $self->process_120bit($msg);
  } else {
    print "L: $length  H: ", unpack("H*",$msg), "\n";
  }
  return $res;
}

=head2 C<is_duplicate( $message )>

This method returns true if this message has been seen in the
previous C<duplicate_timeout> seconds.

=cut

sub is_duplicate {
  my $self = shift;
  my $key = shift;
  my $t = Time::HiRes::time;
  my $l = $self->{_cache}->{$key};
  $self->{_cache}->{$key} = $t;
  return (defined $l && $t-$l < $self->{_duplicate_timeout});
}

=head2 C<process_32bit( $message )>

This method processes a 32-bit message and returns an array references
containing any xPL messages that can be constructed from the decoded
message.

For details of the protocol see:

  http://www.wgldesigns.com/protocols/rfxcomrf32_protocol.txt

=cut

sub process_32bit {
  my $self = shift;
  my $message = shift;
  my @bytes = unpack("C*",$message);
  if ($self->is_x10(\@bytes)) {
    return $self->parse_x10($message, \@bytes);
  }

  if ($self->is_x10_security(\@bytes)) {
    return $self->parse_x10_sec($message, \@bytes);
  }

  print "Bogus ", unpack("H*",$message), "\n";
  return [];
}

=head2 C<reverse_bits( \@bytes )>

This method reverses the bits in the bytes.

=cut

sub reverse_bits {
  my $self = shift;
  my $bytes = shift;
  foreach (@$bytes) {
    $_ = unpack("C",pack("B8",unpack("b8", pack("C",$_))));
  }
  return 1;
}

=head2 C<process_48bit( $message )>

This method processes a 48-bit message and returns an array references
containing any xPL messages that can be constructed from the decoded
message.

=cut

sub process_48bit {
  my $self = shift;
  my $message = shift;
  my @bytes = unpack("C*",$message);
  print "48bit: ", unpack("H*",$message), "\n";
  if ($self->is_x10_security(\@bytes)) {
    return $self->parse_x10_sec($message, \@bytes);
  }
  if ($bytes[0] == ($bytes[1]^0xf0)) {
    return $self->parse_rfxcom($message, \@bytes);
  }
  return [];
}

=head2 C<process_120bit( $message )>

This method processes a 120-bit message and returns an array references
containing any xPL messages that can be constructed from the decoded
message.

=cut

sub process_120bit {
  my $self = shift;
  my $message = shift;
  my @bytes = unpack("C*",$message);
  print "120bit: ", unpack("H*",$message), "\n";
  if ($bytes[0] == 0xea && ($bytes[1]&0xf0) == 0x00) {
    return $self->parse_electrisave($message, \@bytes);
  }
  return [];
}

sub parse_electrisave {
  my $self = shift;
  my $message = shift;
  my $bytes = shift;
  my $device = sprintf "%02x", $bytes->[2];
  my $amps = ( $bytes->[3]+(($bytes->[4]&0x3)<<8) ) / 10;
  my $kwh = ($amps*240)/1000;
  my $pence = 7.572*$kwh;
  printf "electrisave c=%.2f p=%.2f\n", $amps, $pence;
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'sensor.basic',
                            head => { source => $self->{_source}, },
                            body => {
                                     device => 'electrisave.'.$device,
                                     type => 'current',
                                     current => $amps,
                                    }
                           )];
  return [];
}

sub parse_rfxcom {
  my $self = shift;
  my $message = shift;
  my $bytes = shift;
#http://board.homeseer.com/showpost.php?p=749725&postcount=27
#http://board.homeseer.com/showpost.php?p=767406&postcount=88
  my $device = sprintf "%02x", $bytes->[0];
  my $type = ($bytes->[5]&0xf0)>>4;
  my $check = $bytes->[5]&0xf;
  my $nibble_sum = 0;
  $nibble_sum += ($bytes->[$_]&0xf) + (($bytes->[$_]&0xf0)>>4) foreach (0..4);
  my $parity = 0xf^($nibble_sum&0xf);
  unless ($parity == $bytes->[5]) {
    print "rfxcom: ", unpack("H*",$message), "\n";
  }

  my $time =
    { 0x01 => '30s',
      0x02 => '1m',
      0x04 => '5m',
      0x08 => '10m',
      0x10 => '15m',
      0x20 => '30m',
      0x40 => '45m',
      0x80 => '60m',
    };
  my $type_str =
      [
       'normal data packet',
       'new interval time set',
       'calibrate value',
       'new address set',
       'counter value reset to zero',
       'set 1st digit of counter value integer part',
       'set 2nd digit of counter value integer part',
       'set 3rd digit of counter value integer part',
       'set 4th digit of counter value integer part',
       'set 5th digit of counter value integer part',
       'set 6th digit of counter value integer part',
       'counter value set',
       'set interval mode within 5 seconds',
       'calibration mode within 5 seconds',
       'set address mode within 5 seconds',
       'identification packet',
      ]->[$type];
  unless ($type == 0) {
    print "rfxpower: ", unpack("H*",$message), " ", $type_str, "\n";
    return [];
  }
  my $kwh = ( ($bytes->[2]<<16) + ($bytes->[3]<<8) + ($bytes->[4]) ) / 100;
  print "rfxpower: ", $kwh, "kwh\n";
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'sensor.basic',
                            head => { source => $self->{_source}, },
                            body => {
                                     device => 'rfxpower.'.$device,
                                     type => 'energy',
                                     current => $kwh,
                                    }
                           )];
}

sub is_x10 {
  my $self = shift;
  my $bytes = shift;
  # bits are not reversed yet!
  return ($bytes->[2]^0xff) == $bytes->[3] &&
    ($bytes->[0]^0xff) == $bytes->[1] &&
      !($bytes->[2]&0x7)
}

=head2 C<parse_x10( $message )>

TODO: POD

TODO: The duplicates should probably be counted for bright and dim to set
the level but they aren't yet.

=cut

sub parse_x10 {
  my $self = shift;
  my $message = shift;
  my $bytes = shift;

  $self->reverse_bits($bytes);

  my $byte1 = $bytes->[2];
  my $byte3 = $bytes->[0];

  my $h = house_code($byte3);
  my $f = function($byte1);
  unless ($byte1&1) {
    $self->{_unit}->{$h} = unit_code($byte1, $byte3);
  }
  my $u = $self->{_unit}->{$h} ||
    do { warn "Don't have unit code for: $h $f\n"; return };
  my $k = $h.$u." ".$f;
  print $k, "\n" if ($self->{_verbose});
  return [$self->x10_xpl_message($f, $h.$u)];
}

sub is_x10_security {
  my $self = shift;
  my $bytes = shift;
  # bits are not reversed yet!
  return  ($bytes->[0]^0x0f) == $bytes->[1] && ($bytes->[2]^0xff) == $bytes->[3]
}

sub parse_x10_sec {
  my $self = shift;
  my $message = shift;
  my $bytes = shift;

  $self->reverse_bits($bytes);

  my $device = sprintf('x10sec%02x',$bytes->[0]);
  my $data = $bytes->[2];

  my %not_supported_yet =
    (
     # See: http://www.wgldesigns.com/protocols/w800rf32_protocol.txt
     0x70 => 'SH624 arm home (min)',
     0x60 => 'SH624 arm away (min)',
     0x50 => 'SH624 arm home (max)',
     0x40 => 'SH624 arm away (max)',
     0x41 => 'SH624 disarm',
     0x42 => 'SH624 sec light on',
     0x43 => 'SH624 sec light off',
     0x44 => 'SH624 panic',
     #0x60 => 'KF574 arm',
     0x61 => 'KF574 disarm',
     0x62 => 'KF574 lights on',
     0x63 => 'KF574 lights off',
    );

  if (exists $not_supported_yet{$data}) {
    warn sprintf "Not supported: %02x %s\n", $data, $not_supported_yet{$data};
    return [];
  }

  my $alert = !($data&0x1);
  my $tamper = $data&0x2;
  my $min_delay = $data&0x20;
  my $low_battery = $data&0x80;

  my $k = $device.' '.
    ($alert ? 'alert' : 'normal').' '.
      ($min_delay ? 'min' : 'max').' '.
        ($tamper ? 'tamper ' : '').
          ($low_battery ? 'lowbat' : '');

  my @res;
  my %args =
    (
     message_type => 'xpl-trig',
     class => 'security.zone',
     head => { source => $self->{_source}, },
     body => {
              event => 'alert',
              zone  => $device,
              state => $alert ? 'true' : 'false',
             }
    );
  push @res, xPL::Message->new(%args);
#x10.security
#{
#command=alert|normal|motion|light|dark|arm-home|arm-away|disarm|panic|lights-on|lights-off
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
     head => { source => $self->{_source}, },
     body => {
              command => $alert ? ($data&0x30 ? 'motion' : 'alert') : 'normal',
              device  => $device,
             }
    );
  $args{'tamper'} = 'true' if ($tamper);
  $args{'low-battery'} = 'true' if ($low_battery);
  $args{'delay'} = $min_delay ? 'min' : 'max';
  push @res, xPL::Message->new(%args);
  return \@res;
}

=head2 C<house_code( $byte1 )>

This function takes byte 1 of a processed X10 message sequence and
returns the associated house code.

=cut

sub house_code {
  ('m', 'e', 'c', 'k', 'o', 'g', 'a', 'i',
   'n', 'f', 'd', 'l', 'p', 'h', 'b', 'j')[$_[0] & 0xf];
}

=head2 C<function( $byte1 )>

This function takes byte 1 of a processed X10 message sequence and
returns the associated function.

=cut

sub function {
  $_[0]&0x1 ? ($_[0]&0x8 ? "dim" : "bright") : ($_[0]&0x4 ? "off" : "on");
}

=head2 C<unit_code( $byte1, $byte3 )>

This function takes bytes 1 and 3 of a processed X10 message sequence
and returns the associated unit code.

=cut

sub unit_code {
  my $b1 = shift;
  my $b3 = shift;
  return 1 + ((($b1&0x2) << 1) +
              (($b1&0x18) >> 3) +
              (($b3&0x20) >> 2));
}

=head2 C<x10_xpl_message( $command, $device, $level )>

This functions is used to construct x10.basic xpl-trig messages as a
result of RF messages decoded from the RF data.

=cut

sub x10_xpl_message {
  my $self = shift;
  my $command = shift;
  my $device = shift;
  my $level = shift;
  my %body = ( device => $device, command => $command );
  if ($command eq "bright" or $command eq "dim") {
    $body{level} = $level || $self->{_default_x10_level};
  }
  my %args =
    (
     message_type => 'xpl-trig',
     class => 'x10.basic',
     head => { source => $self->{_source}, },
     body => \%body,
    );
  return xPL::Message->new(%args);
}

=head2 C<hex_dump( $message )>

This method converts the given message to a hex string.

=cut

sub hex_dump {
  my $message = shift;
  return ~~unpack('H*', $message);
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
