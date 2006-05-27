package xPL::Message::audio::basic;

# $Id: basic.pm 46 2005-12-11 22:06:30Z beanz $

=head1 NAME

xPL::Message::audio::basic - Perl extension for audio.basic class xPL messages

=head1 SYNOPSIS

  use xPL::Message;

  my $cmnd = xPL::Message->new(message_type => "xpl-cmnd",
                               class => 'audio', class_type => 'basic',
                               command => 'play');

=head1 DESCRIPTION

This module creates an xPL message with a schema class and type of
'audio.basic'.

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
our $VERSION = qw/$Revision: 46 $/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'command',
    validation =>
      xPL::Validation->new(
        type => 'Pattern',
        pattern => '(play|stop|volume\s?[-+<>]?\d+|skip|back|random|clear)',
      ),
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
  return "xpl-cmnd";
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '.($self->command||$self->status);
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_AUDIO.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
