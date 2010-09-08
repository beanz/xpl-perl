package xPL::RF;

=head1 NAME

xPL::RF - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF;

=head1 DESCRIPTION

This is a module for handling the decoding of RF messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Time::HiRes;
use xPL::Message;
use Module::Pluggable
  search_path => 'xPL::RF', sub_name => 'parsers', require => 1;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(hex_dump) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision$/[1];

my $EXCLAMATION = q{!};

my @parsers = __PACKAGE__->parsers();

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
  $self->verbose($p{verbose});
  $self->{_default_x10_level} = 10;
  $self->{_duplicate_timeout} = $p{duplicate_timeout} || .5;
  $self->{_cache} = {};
  return $self;
}

=head2 C<verbose( [ $new_setting ] )>

This is a getter/setter method for the verbosity setting for the RF parser.

=cut

sub verbose {
  my $self = shift;
  if (@_) {
    $self->{_verbose} = $_[0];
  }
  return $self->{_verbose};
}

=head2 C<stash( $key, $value )>

This method is intended for use by parser plugins to store
persistent data.  This method stores the given value against
the given key.

=cut

sub stash {
  my $self = shift;
  my $key = shift;
  my $value = shift;
  return $self->{_stash}->{$key} = $value;
}

=head2 C<unstash( $key )>

This method is intended for use by parser plugins to store persistent
data.  This method retrieves the value previously stored with a call
to the C<stash> method with the same given key.

=cut

sub unstash {
  my $self = shift;
  my $key = shift;
  return $self->{_stash}->{$key};
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
  my ($hdr_byte, @bytes) = unpack 'C*', $buf;
  if ($hdr_byte == 0x2c || $hdr_byte == 0x4d) {
    # skip responses
    return;
  }

  # TODO: master/slave ?
  my $length_bits = $hdr_byte & 0x7f;
  return { length => 1 } if ($length_bits == 0);
  my $length = $length_bits / 8;
  if (scalar @bytes < $length) {
    # not enough data in buffer
    return { length => 0 };
  }
  if ($length != int $length) {
    # not a whole number of bytes so we must round it up
    $length = 1 + int $length;
  }
  my $res = { length => $length+1 };
  my $msg = substr $buf, 1, $length; # message from buffer
  if ($self->is_duplicate($length_bits, $msg)) {
    $res->{duplicate} = 1;
    return $res;
  }
  my @msg_bytes = unpack 'C*', $msg;
  foreach my $parser (@parsers) {
    my $messages = $parser->parse($self, $msg, \@msg_bytes, $length_bits);
    next unless (defined $messages);
    $res->{messages} = $messages;
    return $res;
  }
  if ($self->verbose) {
    warn "Unknown message, len=$length_bits:\n  ", (unpack 'H*', $msg), "\n";
  }
  return $res;
}

=head2 C<is_duplicate( $length_bits, $message )>

This method returns true if this message has been seen in the
previous C<duplicate_timeout> seconds.

=cut

sub is_duplicate {
  my $self = shift;
  my $bits = shift;
  my $message = shift;
  my $key = $bits.$EXCLAMATION.$message;
  my $t = Time::HiRes::time;
  my $l = $self->{_cache}->{$key};
  $self->{_cache}->{$key} = $t;
  return defined $l && $t-$l < $self->{_duplicate_timeout};
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
  return [] if ($self->is_duplicate(32, $message));
  my @bytes = unpack 'C*', $message;

  foreach my $parser ($self->parsers()) {
    my $messages = $parser->parse($self, $message, \@bytes, 32);
    next unless ($messages);
    return $messages;
  }
  return [];
}

=head2 C<reverse_bits( \@bytes )>

This method reverses the bits in the bytes.

=cut

sub reverse_bits {
  my $self = shift;
  my $bytes = shift;
  foreach (@$bytes) {
    $_ = unpack 'C',(pack 'B8', (unpack 'b8', (pack 'C',$_)));
  }
  return 1;
}

=head2 C<hex_dump( $message )>

This method converts the given message to a hex string.

=cut

sub hex_dump {
  my $message = shift;
  return ~~unpack 'H*', $message;
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
