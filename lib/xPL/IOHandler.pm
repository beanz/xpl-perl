package xPL::IOHandler;

=head1 NAME

xPL::IOHandler - a helper module for queuing writes and processing reads

=head1 SYNOPSIS

  use xPL::IOHandler;

  sub process_buffer {
    my ($buffer, $last_sent) = @_;
    ...
    return $buffer; # any unprocessed bytes
  }
  my $io_queue = xPL::IOHandler->new(handle => $fh,
                                     reader_callback => \&process_buffer);
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an helper module for reading and writing to an IO Handle,
There are several usage examples provided by the xPL Perl distribution.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use FileHandle;
use IO::Socket::INET;
use Time::HiRes;
use xPL::Base;
use xPL::Queue;

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our @FIELDS = qw/xpl
                 handle input_handle output_handle
                 input_record_type
                 output_record_type
                 reader_callback
                 ack_timeout
                 ack_timeout_callback
                 discard_buffer_timeout/;
__PACKAGE__->make_readonly_accessor($_) foreach (@FIELDS);

=head2 C<new(%params)>

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  my $self =
    {
     _input_record_type => 'xPL::IORecord::Simple',
     _output_record_type => 'xPL::IORecord::Simple',
    };
  if ($p{device}) {
    $p{handle} = $pkg->device_open($p{device}, $p{baud}, $p{port});
  }
  foreach ('verbose', @FIELDS) {
    next unless (exists $p{$_});
    $self->{'_'.$_} = $p{$_};
  }
  bless $self, $pkg;
  my $xpl = $self->{_xpl};
  foreach my $c ($self->{_input_record_type}, $self->{_output_record_type}) {
    eval " require $c; import $c; ";
    die $@ if ($@);
  }
  $xpl->add_input(handle => $self->input_handle,
                  callback => sub {
                    my ($handle, $obj) = @_;
                    return $obj->reader_wrapper($handle);
                  },
                  arguments => $self);
  $self->{_q} = xPL::Queue->new;
  $self->{_buffer} = '';
  return $self;
}

=head2 C<device_open( $device, [$baud] )>

Helper that opens a device where the device is either a serial port
or a server of the form C<ip-address:port>.  This helper dies on
failure.

=cut

sub device_open {
  my ($self, $dev, $baud, $port) = @_;
  my $fh;
  if ($dev =~ /\//) {
    if (-S $dev) {
      $fh = IO::Socket::UNIX->new($dev)
        or $self->argh("Unix domain socket connect to '$dev' failed: $!\n");
    } else {
      # TODO: use Device::SerialPort?
      system("stty -F $dev ospeed $baud pass8 raw -echo >/dev/null") == 0 or
        $self->argh("Setting serial port with stty failed: $!\n");
      $fh = FileHandle->new;
      sysopen($fh, $dev,O_RDWR|O_NOCTTY|O_NDELAY)
        or $self->argh("open of '$dev' failed: $!\n");
      $fh->autoflush(1);
      binmode($fh);
    }
  } else {
    $dev .= ':'.($port||'10001') unless ($dev =~ /:/);
    $fh = IO::Socket::INET->new($dev)
      or $self->argh("TCP connect to '$dev' failed: $!\n");
  }
  return $fh;
}

=head2 C<input_handle()>

Returns the file handle being used for input.

=cut

sub input_handle {
  $_[0]->{_input_handle} or $_[0]->{_input_handle} = $_[0]->{_handle};
}

=head2 C<output_handle()>

Returns the file handle being used for output.

=cut

sub output_handle {
  $_[0]->{_output_handle} or $_[0]->{_output_handle} = $_[0]->{_handle};
}

=head2 C<discard_buffer_check()>

This method is called when the handle is ready for reads.  It empties
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

=head2 C<read( )>

This method is called when the handle is ready for reads.  It calls
L<discard_buffer_check()> and reads new data.  If no data is ready it
dies with an appropriate error.

=cut

sub read {
  my ($self, $handle) = @_;
  $self->discard_buffer_check();
  my $bytes =
    $handle->sysread($self->{_buffer}, 2048, length($self->{_buffer}));
  unless ($bytes) {
    $self->argh("failed: $!\n") unless (defined $bytes);
    $self->argh("closed\n");
  }
  $self->{_last_read} = Time::HiRes::time;
  return 1;
}

=head2 C<reader_wrapper( $handle )>

This method is called when the handle is ready for reads.  It manages
the calls to the C<reader_callback>.  Alternatively, clients could
just override this method to implement specific behaviour.

=cut

sub reader_wrapper {
  my ($self, $handle) = @_;
  my $bytes = $self->read($handle);
  while (length $self->{_buffer}) {
    my $obj = $self->{_input_record_type}->read($self->{_buffer});
    defined $obj or last;
    if (ref $obj) {
      $self->{_reader_callback}->($self, $obj, $self->{_waiting}) &&
        $self->write_next();
    } else {
      $obj && $self->write_next();
      last;
    }
  }
  return 1;
}


=head2 C<write( $message )>

This method is used to queue messages to be sent to the IO handle.

=cut

sub write {
  my $self = shift;
  my $msg = ref $_[0] ? $_[0] : $self->{_output_record_type}->new(@_);
  $self->{_q}->enqueue($msg);
  $self->info('queued: ', $msg, "\n");
  if (!defined $self->{_waiting}) {
    return $self->write_next();
  }
  return 1;
}


=head2 C<write_next( )>

This method writes the next waiting message (if there is one) to the
handle.

=cut

sub write_next {
  my $self = shift;
  my $xpl = $self->xpl;
  my $msg = $self->{_q}->dequeue;
  undef $self->{_waiting};
  $xpl->remove_timer('!waiting'.$self)
    if ($xpl->exists_timer('!waiting'.$self));
  return if (!defined $msg);
  my $fh = $self->output_handle;
  $self->info('sending: ', $msg, "\n");
  my $out = $msg->out;
  syswrite($fh, $out, length($out));
  $self->{_waiting} = $msg;
  my $ack_timeout = $self->{_ack_timeout};
  if (defined $ack_timeout) {
    $xpl->add_timer(id => '!waiting'.$self, timeout => $ack_timeout,
                    callback => sub {
                      $self->{_ack_timeout_callback}->($self,
                                                       $self->{_waiting})
                        if (defined $self->{_ack_timeout_callback});
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
