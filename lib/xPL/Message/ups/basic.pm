package xPL::Message::ups::basic;

# $Id$

=head1 NAME

xPL::Message::ups::basic - Perl extension for an ups.basic class xPL message

=head1 SYNOPSIS

  use xPL::Message;

  my $cmnd = xPL::Message->new(message_type => "xpl-trig",
                               class => 'ups', class_type => 'basic',
                               status => 'mains', event => 'onmains');

  my $trig = xPL::Message->new(class => 'ups.basic',
                               status => 'battery', event => 'onbattery');

=head1 DESCRIPTION

This module creates an xPL message with a schema class and type of
'ups.basic'.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use xPL::Message;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Message);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'status',
    validation =>
      xPL::Validation->new(type => 'Set', set => [qw/mains battery unknown/]),
    die => 1,
    required => 1,
   },
   {
    name => 'event',
    validation =>
      xPL::Validation->new(type => 'Set',
                           set =>
                           [
                            qw/onmains onbattery
                               battlow battfull bti btp btf
                               comms_lost comms_ok
                               input_freq_error input_freq_ok
                               input_voltage_high input_voltage_low
                               input_voltage_ok
                               output_voltage_high output_voltage_low
                               output_voltage_ok
                               output_overload output_ok
                               temp_high temp_ok
                              /
                           ]),
    die => 1,
    required => 1,
   },
  ];
}

=head2 C<default_message_type()>

This method returns the default message type for this xPL message
schema.  It returns 'xpl-trig' since this is the only unique message
type defined by this message schema.

=cut

sub default_message_type {
  return "xpl-trig";
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '.$self->status.' '.$self->event;
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_UPS.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
