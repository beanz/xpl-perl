package xPL::RF::RFXCOM;

# $Id$

=head1 NAME

xPL::RF::RFXCOM - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::RFXCOM;

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
use Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision$/[1];

=head2 C<parse( $parent, $message, $bytes, $bits )>

TODO: POD

TODO: The duplicates should probably be counted for bright and dim to set
the level but they aren't yet.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 48 or return;

  ($bytes->[0] == ($bytes->[1]^0xf0)) or return;

#http://board.homeseer.com/showpost.php?p=749725&postcount=27
#http://board.homeseer.com/showpost.php?p=767406&postcount=88
  my $device = sprintf "%02x", $bytes->[0];
  my $type = ($bytes->[5]&0xf0)>>4;
  my $check = $bytes->[5]&0xf;
  my $nibble_sum = 0;
  $nibble_sum += ($bytes->[$_]&0xf) + (($bytes->[$_]&0xf0)>>4) foreach (0..4);
  my $parity = 0xf^($nibble_sum&0xf);
  unless ($parity == $check) {
    warn "RFXCOM parity error $parity != $check\n";
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
    warn "Unsupported rfxpower message $type_str\n",
         "H:: ", unpack("H*",$message), "\n";
    return [];
  }
  my $kwh = ( ($bytes->[2]<<16) + ($bytes->[3]<<8) + ($bytes->[4]) ) / 100;
  #print "rfxpower: ", $kwh, "kwh\n";
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'sensor.basic',
                            head => { source => $parent->source, },
                            body => {
                                     device => 'rfxpower.'.$device,
                                     type => 'energy',
                                     current => $kwh,
                                    }
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

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005, 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut