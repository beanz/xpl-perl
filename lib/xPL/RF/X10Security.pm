package xPL::RF::X10Security;

# $Id$

=head1 NAME

xPL::RF::X10Security - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::X10Security;

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
#use AutoLoader qw(AUTOLOAD);

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

  ($bits == 32 || $bits == 41) or return;

  # bits are not reversed yet!
  (($bytes->[0]^0x0f) == $bytes->[1] && ($bytes->[2]^0xff) == $bytes->[3])
    or return;

  $parent->reverse_bits($bytes);

  my $device = sprintf 'x10sec%02x', $bytes->[0];
  my $short_device = $bytes->[0];
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

  my @res;
  my %args =
    (
     message_type => 'xpl-trig',
     class => 'security.zone',
     head => { source => $parent->source, },
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
     head => { source => $parent->source, },
     body => {
              command => $alert ? 'alert' : 'normal',
              device  => $short_device,
             }
    );
  $args{'body'}->{'tamper'} = 'true' if ($tamper);
  $args{'body'}->{'low-battery'} = 'true' if ($low_battery);
  $args{'body'}->{'delay'} = $min_delay ? 'min' : 'max';
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
