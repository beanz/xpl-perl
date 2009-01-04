package xPL::RF::X10Security;

# $Id$

=head1 NAME

xPL::RF::X10Security - Perl extension for decoding X10 Security device messages

=head1 SYNOPSIS

  use xPL::RF::X10Security;

=head1 DESCRIPTION

This is a module for decoding RF messages from X10 Security devices.

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

This method attempts to recognize and parse RF messages corresponding
to X10 Security messages.  If messages are identified a
reference to a list of xPL::Message objects is returned.  If the
message is not recognized, undef is returned.

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
     #0x60 => 'SH624 arm away (min)',
     0x50 => 'SH624 arm home (max)',
     0x40 => 'SH624 arm away (max)',
     0x41 => 'SH624 disarm',
     0x42 => 'SH624 sec light on',
     0x43 => 'SH624 sec light off',
     0x44 => 'SH624 panic',
     0x60 => 'arm-away',
     0x61 => 'disarm',
     0x62 => 'lights-on',
     0x63 => 'lights-off',
    );

  my %x10_security =
    (
     0x60 => ['arm-away', 'min'],
     0x61 => 'disarm',
     0x62 => 'lights-on',
     0x63 => 'lights-off',
    );

  my $command;
  my $tamper;
  my $min_delay;
  my $low_battery;

  my @res;
  my %args;
  if (exists $x10_security{$data}) {
    my $rec = $x10_security{$data};
    my $min_delay;
    if (ref $rec) {
      ($command, $min_delay) = @$rec;
    } else {
      $command = $rec;
    }

    %args = (
             message_type => 'xpl-trig',
             class => 'security.basic',
             head => { source => $parent->source, },
             body => {
                      command => $command,
                      user => $device,
                     }
            );
    $args{'body'}->{'delay'} = $min_delay if (defined $min_delay);
    push @res, xPL::Message->new(%args);

  } elsif (exists $not_supported_yet{$data}) {
    warn sprintf "Not supported: %02x %s\n", $data, $not_supported_yet{$data};
    return [];
  } else {

    my $alert = !($data&0x1);
    $command = $alert ? 'alert' : 'normal',
    $tamper = $data&0x2;
    $min_delay = $data&0x20 ? 'min' : 'max';
    $low_battery = $data&0x80;

    %args =
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
    $args{'body'}->{'tamper'} = 'true' if ($tamper);
    $args{'body'}->{'low-battery'} = 'true' if ($low_battery);
    $args{'body'}->{'delay'} = $min_delay;
    push @res, xPL::Message->new(%args);
  }

  %args =
    (
     message_type => 'xpl-trig',
     class => 'x10.security',
     head => { source => $parent->source, },
     body => {
              command => $command,
              device  => $short_device,
             }
    );
  $args{'body'}->{'tamper'} = 'true' if ($tamper);
  $args{'body'}->{'low-battery'} = 'true' if ($low_battery);
  $args{'body'}->{'delay'} = $min_delay if (defined $min_delay);
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

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
