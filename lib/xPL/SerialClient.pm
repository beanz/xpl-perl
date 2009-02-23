package xPL::SerialClient;

=head1 NAME

xPL::SerialClient - Perl extension for an xPL Serial Device Client

=head1 SYNOPSIS

  use xPL::SerialClient;

  sub process_buffer {
    my ($xpl, $buffer, $last_sent) = @_;
    ...
    return $buffer; # any unprocessed bytes
  }
  my $xpl = xPL::SerialClient->new(reader_callback => \&process_buffer);
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client for a serial port-based device.  There
are several usage examples provided by the xPL Perl distribution.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use FileHandle;
use Getopt::Long;
use Time::HiRes;
use IO::Socket::INET;
use Pod::Usage;
use xPL::Client;
use xPL::Queue;

use Exporter;
our @ISA = qw(xPL::Client);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device
                                                    device_handle
                                                    reader_callback
                                                    ack_timeout
                                                    ack_timeout_callback
                                                    discard_buffer_timeout
                                                    output_record_separator/);

=head2 C<new(%params)>

The constructor creates a new xPL::SerialClient object.  The
constructor takes a parameter hash as arguments.  Valid parameters in
the hash are those described in L<xPL::Client> and the following
additional elements:

=over 4

=item device

  The device to use for this client.

=item baud

  The baud rate for the device.  The default is 9600.

=item reader_callback

  The code ref to call when the read buffer changes.

=item ack_timeout

  If defined it is the amount of time in seconds to wait before
  assuming that the client is ready for more input.  The default is
  undefined which means wait forever (for a response).

=item ack_timeout_callback

  Only valid if the ack_timeout is specified.  This callback is
  executed if the ack_timeout expires.

=item discard_buffer_timeout

  Discard the contents of the input buffer if it is non-empty and
  unprocessed after this many seconds.  Default is to wait forever
  for a complete record to arrive.

=item getopts

  Additional arguments to C<Getopt::Long::GetOptions>.  Default is none.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }

  my %p = @_;

  my $name = $0;
  $name =~ s/.*xpl-//g; $name =~ s/-//g;

  my %args = ( vendor_id => 'bnz', device_id => $p{name} || $name, );
  my %opt = ();
  my $verbose;
  my $interface;
  my $help;
  my $man;
  my $baud = $p{baud} || 9600;
  GetOptions('verbose+' => \$verbose,
             'interface=s' => \$interface,
             'baud=i' => \$baud,
             'define=s' => \%opt,
             'help|?|h' => \$help,
             'man' => \$man,
             @{$p{getopts}|| [] }
            ) or pod2usage(2);
  pod2usage(1) if ($help);
  pod2usage(-exitstatus => 0, -verbose => 2) if ($man);
  $args{'interface'} = $interface if ($interface);
  $args{'verbose'} = $verbose if ($verbose);

  my $dev = shift @ARGV or
    pod2usage(-message => "The device parameter is required",
              -exitstatus => 1);

  # Create an xPL Client object
  my $self = $pkg->SUPER::new(%args, %opt) or
    die "Failed to create xPL::Client\n";

  my $fh;
  if ($dev =~ /\//) {
    # TODO: use Device::SerialPort?
    system("/bin/stty -F $dev ospeed $baud pass8 raw >/dev/null") == 0 or
      die "Setting serial port with stty failed: $!\n";
    $fh = FileHandle->new;
    sysopen($fh, $dev,O_RDWR|O_NOCTTY|O_NDELAY)
      or die "Cannot open serial connection on device '$dev'\n";
    $fh->autoflush(1);
    binmode($fh);
  } else {
    $dev .= ':10001' unless ($dev =~ /:/);
    $fh = IO::Socket::INET->new($dev)
      or die "Cannot TCP connection to device at '$dev'\n";
  }
  $self->add_input(handle => $fh,
                   callback => sub {
                     my ($handle, $args) = @_;
                     return $args->[0]->device_reader($handle, $args);
                   },
                   arguments => [$self]);
  $self->{_device_handle} = $fh;
  $self->{_reader_callback} = $p{reader_callback};
  $self->{_ack_timeout} = $p{ack_timeout};
  $self->{_ack_timeout_callback} = $p{ack_timeout_callback};
  $self->{_discard_buffer_timeout} = $p{discard_buffer_timeout};
  $self->{_output_record_separator} = $p{output_record_separator};
  $self->{_q} = xPL::Queue->new;
  $self->{_buf} = '';
  return $self;
}

=head2 C<device_reader( $handle )>

This method is called when the device is ready for reads.  It manages
the calls to the C<reader_callback>.  Alternatively, clients could
just override this method to implement specific behaviour.

=cut

sub device_reader {
  my ($self, $handle) = @_;
  if ($self->{_discard_buffer_timeout}) {
    if ($self->{_buf} ne '' &&
        $self->{_last_read} < (Time::HiRes::time -
                               $self->{_discard_buffer_timeout})) {
      print STDERR "Discarding: ", (unpack 'H*', $self->{_buf}), "\n";
      $self->{_buf} = '';
    }
  }
  my $bytes = $handle->sysread($self->{_buf}, 2048, length($self->{_buf}));
  unless ($bytes) {
    die "Serial read failed: $!\n" unless (defined $bytes);
    die "Serial device closed\n";
  }
  $self->{_last_read} = Time::HiRes::time;
  $self->{_buf} =
    $self->{_reader_callback}->($self, $self->{_buf}, $self->{_waiting});
  $self->write_next();
  return 1;
}

=head2 C<write( $message )>

This method is used to queue messages to be sent to the serial device.

=cut

sub write {
  my ($self, $msg) = @_;
  $self->{_q}->enqueue($msg);
  print 'queued: ', $msg, "\n" if ($self->verbose);
  if (!defined $self->{_waiting}) {
    return $self->write_next();
  }
  return 1;
}


=head2 C<write_next( )>

This method writes the next waiting message (if there is one) to the
serial device.

=cut

sub write_next {
  my $self = shift;
  my $msg = $self->{_q}->dequeue;
  undef $self->{_waiting};
  $self->remove_timer('!waiting') if ($self->exists_timer('!waiting'));
  return if (!defined $msg);
  my $fh = $self->device_handle;
  print 'sending: ', $msg, "\n" if ($self->verbose);
  my $raw = ref $msg ? $msg->raw : $msg;
  my $ors = $self->{_output_record_separator};
  $raw .= $ors if (defined $ors);
  syswrite($fh, $raw, length($raw));
  $self->{_waiting} = $msg;
  my $ack_timeout = $self->{_ack_timeout};
  if (defined $ack_timeout) {
    $self->add_timer(id => '!waiting', timeout => $ack_timeout,
                    callback => sub {
                      defined $self->{_ack_timeout_callback} and
                        $self->{_ack_callback}->($self, $self->{_waiting});
                      $self->write_next(); 1; });
  }
  $fh->flush();
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
