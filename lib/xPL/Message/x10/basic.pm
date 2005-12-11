package xPL::Message::x10::basic;

# $Id$

=head1 NAME

xPL::Message::x10::basic - Perl extension for an x10.basic class xPL message

=head1 SYNOPSIS

  use xPL::Message;

  my $cmnd = xPL::Message->new(class => 'x10', class_type => 'basic',
                               command => 'ON', device => 'j10');

  my $trig = xPL::Message->new(message_type => 'xpl-trig',
                               class => 'x10', class_type => 'basic',
                               command => 'DIM', device => 'g4,g5',
                               level => '40');

=head1 DESCRIPTION

This module creates an xPL message with a schema class and type of
'x10.basic'.

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
    name => 'command',
    validation =>
      xPL::Validation->new(type => 'Set',
                           set =>
                           [
                            qw/select
                            all_units_off all_units_on
                            all_lights_on all_lights_off
                            on off dim bright
                            extended
                            hail_req hail_ack
                            predim1 predim2
                            status status_on status_off
                           /
                           ]),
    die => 1,
   },
   {
    name => 'device',
    validation =>
      xPL::Validation->new(
        type => 'Pattern',
        pattern => '[A-Pa-p]([1-9]|1[0-6])(,\s*[A-Pa-p]([1-9]|1[0-6]))*'),
    error =>
      q{It should be a comma-separated list of devices - e.g. 'A1,F12,G9'.}
   },
   {
    name => 'house',
    validation => xPL::Validation->new(type => 'Pattern',
                                       pattern => '[A-Pa-p]+'),
    error => q{It should be a list of house codes - e.g. 'AFG'.}
   },
   {
    name => 'level',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => 0, max => 100),
   },
   {
    name => 'data1',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => 0, max => 255),
   },
   {
    name => 'data2',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => 0, max => 255),
   }
  ];
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '.
    $self->command.' '.($self->device ? $self->device : $self->house);
}

=head2 C<command( [ $new_command ] )>

This method returns the x10 command.  If the optional new value
argument is present, then this method updates the x10 command
with the new value before it returns.


=head2 C<device( [ $new_device ] )>

This method returns the x10 device list.  If the optional new value
argument is present, then this method updates the x10 device list with
the new value before it returns.  The device list should be a
comma-separated list of x10 devices.


=head2 C<house( [ $new_house ] )>

This method returns the x10 house code list.  If the optional new
value argument is present, then this method updates the x10 house code
list with the new value before it returns.  The house code list should
be an simple list - no separator - of house codes.


=head2 C<level( [ $new_level ] )>

This method returns the x10 bright/dim level.  If the optional new
value argument is present, then this method updates the x10 bright/dim
level with the new value before it returns.  The value should be
between 0 and 100.


=head2 C<data1( [ $new_data1 ] )>

This method returns the x10 data1 value.  If the optional new value
argument is present, then this method updates the x10 command with the
new value before it returns.  This value is the first byte of extended
data.  The value should be between 0 to 255.

=head2 C<data2( [ $new_data2 ] )>

This method returns the x10 data2 value.  If the optional new value
argument is present, then this method updates the x10 command with the
new value before it returns.  This value is the second byte of extended
data.  The value should be between 0 to 255.


=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_X10.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
