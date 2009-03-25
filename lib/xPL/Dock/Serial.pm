package xPL::Dock::Serial;

=head1 NAME

xPL::Dock::Serial - xPL::Dock plugin for a Serial Device

=head1 SYNOPSIS

  use xPL::Dock::Serial;

  sub process_buffer {
    my ($xpl, $buffer, $last_sent) = @_;
    ...
    return $buffer; # any unprocessed bytes
  }
  my $xpl = xPL::Dock::Serial->new(reader_callback => \&process_buffer);
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
use Time::HiRes;
use IO::Socket::INET;
use Pod::Usage;
use xPL::Dock::Plug;
use xPL::Queue;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device buffer
                                                    device_handle
                                                    reader_callback
                                                    ack_timeout
                                                    ack_timeout_callback
                                                    discard_buffer_timeout
                                                    output_record_separator/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_baud} = 9600;
  $self->{_device} = undef;
  return
    (
     'baud=i' => \$self->{_baud},
     'device=s' => \$self->{_device},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);
  $self->required_field($xpl, 'device',
                        'The --device parameter is required', 1);
  $self->device_open($self->{_device});

  $self->{_reader_callback} = $p{reader_callback};
  $self->{_ack_timeout} = $p{ack_timeout};
  $self->{_ack_timeout_callback} = $p{ack_timeout_callback};
  $self->{_discard_buffer_timeout} = $p{discard_buffer_timeout};
  $self->{_output_record_separator} = $p{output_record_separator};
  $self->{_q} = xPL::Queue->new;
  $self->{_buffer} = '';
  return;
}

=head2 C<device_open()>

=cut

sub device_open {
  my ($self, $dev) = @_;
  my $xpl = $self->xpl;
  my $baud = $self->baud;
  my $fh;
  if ($dev =~ /\//) {
    # TODO: use Device::SerialPort?
    system("stty -F $dev ospeed $baud pass8 raw >/dev/null") == 0 or
      $self->argh("Setting serial port with stty failed: $!\n");
    $fh = FileHandle->new;
    sysopen($fh, $dev,O_RDWR|O_NOCTTY|O_NDELAY)
      or $self->argh("open of '$dev' failed: $!\n");
    $fh->autoflush(1);
    binmode($fh);
  } else {
    $dev .= ':10001' unless ($dev =~ /:/);
    $fh = IO::Socket::INET->new($dev)
      or $self->argh("TCP connect to '$dev' failed: $!\n");
  }
  $xpl->add_input(handle => $fh,
                   callback => sub {
                     my ($handle, $obj) = @_;
                     return $obj->device_reader_wrapper($handle);
                   },
                   arguments => $self);
  return $self->{_device_handle} = $fh;
}

=head2 C<discard_buffer_check()>

This method is called when the device is ready for reads.  It empties
the read buffer if there is a C<discard_buffer_timeout> defined and
that time has elapsed since the last read.

=cut

sub discard_buffer_check {
  my ($self) = @_;
  return unless ($self->{_discard_buffer_timeout});
  if ($self->{_buffer} ne '' &&
      $self->{_last_read} < (Time::HiRes::time -
                             $self->{_discard_buffer_timeout})) {
    print STDERR "Discarding: ", (unpack 'H*', $self->{_buffer}), "\n";
    $self->{_buffer} = '';
  }
  return 1;
}

=head2 C<serial_read( )>

This method is called when the device is ready for reads.  It calls
L<discard_buffer_check()> and reads new data.  If no data is ready it
dies with an appropriate error.

=cut

sub serial_read {
  my ($self, $handle) = @_;
  $self->discard_buffer_check();
  my $bytes = $handle->sysread($self->{_buffer}, 2048, length($self->{_buffer}));
  unless ($bytes) {
    $self->argh("failed: $!\n") unless (defined $bytes);
    $self->argh("closed\n");
  }
  $self->{_last_read} = Time::HiRes::time;
  return 1;
}

=head2 C<device_reader_wrapper( $handle )>

This method is called when the device is ready for reads.  It manages
the calls to the C<reader_callback>.  Alternatively, clients could
just override this method to implement specific behaviour.

=cut

sub device_reader_wrapper {
  my ($self, $handle) = @_;
  my $bytes = $self->serial_read($handle);
  $self->{_buffer} =
    $self->{_reader_callback}->($self, $self->{_buffer}, $self->{_waiting});
  $self->write_next();
  return 1;
}

=head2 C<write( $message )>

This method is used to queue messages to be sent to the serial device.

=cut

sub write {
  my ($self, $msg) = @_;
  $self->{_q}->enqueue($msg);
  $self->info('queued: ', $msg, "\n");
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
  my $xpl = $self->xpl;
  my $msg = $self->{_q}->dequeue;
  undef $self->{_waiting};
  $xpl->remove_timer('!waiting') if ($xpl->exists_timer('!waiting'));
  return if (!defined $msg);
  my $fh = $self->device_handle;
  $self->info('sending: ', $msg, "\n");
  my $raw = ref $msg ? $msg->raw : $msg;
  my $ors = $self->{_output_record_separator};
  $raw .= $ors if (defined $ors);
  syswrite($fh, $raw, length($raw));
  $self->{_waiting} = $msg;
  my $ack_timeout = $self->{_ack_timeout};
  if (defined $ack_timeout) {
    $xpl->add_timer(id => '!waiting', timeout => $ack_timeout,
                    callback => sub {
                      defined $self->{_ack_timeout_callback} and
                        $self->{_ack_timeout_callback}->($self,
                                                         $self->{_waiting});
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
