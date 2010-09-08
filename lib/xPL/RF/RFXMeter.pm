package xPL::RF::RFXMeter;

=head1 NAME

xPL::RF::RFXMeter - Perl extension for decoding RFXCOM Meter RF messages

=head1 SYNOPSIS

  use xPL::RF::RFXMeter;

=head1 DESCRIPTION

This is a module for decoding RF messages from RFXCOM RFXMeter devices.

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

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method attempts to recognize and parse RF messages from RFXMeter
devices.  If messages are identified, a reference to a list of
xPL::Message objects is returned.  If the message is not recognized,
undef is returned.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 48 or return;

  ($bytes->[0] == ($bytes->[1]^0xf0)) or return;

  my $device = sprintf "%02x%02x", $bytes->[0], $bytes->[1];
  my $type = hi_nibble($bytes->[5]);
  my $check = lo_nibble($bytes->[5]);
  my $nibble_sum = nibble_sum(5.5, $bytes);
  my $parity = 0xf^($nibble_sum&0xf);
  unless ($parity == $check) {
    warn "RFXMeter parity error $parity != $check\n";
    return;
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
    warn "Unsupported rfxmeter message $type_str\n",
         "Hex: ", unpack("H*",$message), "\n";
   return [];
  }
  my $kwh = ( ($bytes->[4]<<16) + ($bytes->[2]<<8) + ($bytes->[3]) ) / 100;
  #print "rfxmeter: ", $kwh, "kwh\n";
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'sensor.basic',
                            head => { source => $parent->source, },
                            body => [
                                     device => 'rfxmeter.'.$device,
                                     type => 'energy',
                                     current => $kwh,
                                    ]
                           )];
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

Copyright (C) 2007, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
