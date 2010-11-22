package t::Dock;

=head1 NAME

t::Dock - Perl extension for Helper functions for tests.

=head1 SYNOPSIS

  use Test::More tests => 2;
  use t::Dock qw/:all/;
  check_sent_message('description' => $message_string);

=head1 DESCRIPTION

Common functions to make test scripts a bit easier to read.  There are
CPAN modules to do this sort of thing, but most people wont have them
installed and they are pretty trivial functions so to encourage
testing they are included here.

=cut

use 5.006;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(check_sent_message
                                   check_sent_messages
                                  ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];
use Test::More;

our @msg = ();
sub xPL::Dock::_send_aux_string {
  my ($self, $sin, $str) = @_;
  push @msg, $str unless ($str =~ /^hbeat\./m);
  1;
}

=head2 C<check_sent_message($description => $message_string)>

This method checks if the last non-heartbeat message caught with the
C<xPL::Dock::_send_aux_string> overriden method is the provided
method.  It performs one test comparing the strings of the messages
using the description provided.

=cut

sub check_sent_message {
  my ($desc, $string) = @_;
  my $msg = shift @msg;
  if (defined $string) {
    is_deeply([split /\n/, $msg], [split /\n/, $string],
              'message as expected'.($desc ? ' - '.$desc : ''));
  } else {
    is($msg, undef, 'message not expected'.($desc ? ' - '.$desc : ''));
  }
}

=head2 C<check_sent_message($description => $message_string)>

This method checks all the messages caught with the
C<xPL::Dock::_send_aux_string> overriden method is the provided
method.  It performs one test comparing the strings of the messages
using the description provided.

=cut

sub check_sent_messages {
  my ($desc, $string) = @_;
  my $msg = join '', @msg;
  if (defined $string) {
    is_deeply([split /\n/, $msg], [split /\n/, $string],
              'messages as expected'.($desc ? ' - '.$desc : ''));
  } else {
    is($msg, '', 'messages not expected'.($desc ? ' - '.$desc : ''));
  }
  @msg = ();
}

1;
__END__

=head1 EXPORT

Overrides L<xPL::Listener::_send_aux_string> by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
