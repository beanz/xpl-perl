package xPL::Dock::VIOM;

=head1 NAME

xPL::Dock::VIOM - xPL::Dock plugin for a VIOM IO controller

=head1 SYNOPSIS

  use xPL::Dock qw/VIOM/;
  my $xpl = xPL::Dock->new();
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
use Time::HiRes qw/sleep/;
use xPL::IOHandler;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our %state_map =
  (
   Active => 'high', Inactive => 'low',
   high   => 'high', low      => 'low',
   1      => 'high', 0        => 'low',
  );

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_baud} = 9600;
  $self->{_verbose} = 0;
  return (
          'viom-verbose+' => \$self->{_verbose},
          'viom-baud=i' => \$self->{_baud},
          'viom-tty=s' => \$self->{_device},
         );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl,
                        'device', 'The --viom-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  # initialize states
  $self->{_state} = {};
  my $time = time;
  foreach my $num (1..16) {
    $self->state_changed('o', $num, 'low', $time);
    $self->state_changed('i', $num, 'low', $time);
  }

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'viom', callback => \&xpl_in,
                         arguments => $self,
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'control.basic',
                                    type => 'output',
                                   });

  my $io = $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        reader_callback => sub { $self->process_line(@_) },
                        input_record_type => 'xPL::IORecord::CRLFLine',
                        output_record_type => 'xPL::IORecord::CRLFLine',
                        ack_timeout => 0.03,
                        @_);

  $io->write('CSV'); # report software version
  $io->write('CIC1'); # turn on input status change reporting

  # sanity check the inputs immediately and periodically so we keep
  # the current state sane even when viom is unplugged, etc.
  $xpl->add_timer(id => 'input-check', timeout => -631,
                  callback => sub { $self->{_io}->write('CIN'); 1; });

  # sanity check the outputs immediately and periodically so we keep
  # the current state sane even when viom is unplugged, etc.
  $xpl->add_timer(id => 'output-check', timeout => -641,
                  callback => sub { $self->{_io}->write('COR'); 1; });

  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming control.basic schema messages.

=cut

sub xpl_in {
  my %p = @_;
  my $msg = $p{message};
  my $self = $p{arguments};

  return 1 unless ($msg->field('device') =~ /^o(\d+)$/);
  my $num = $LAST_PAREN_MATCH;
  my $command = lc $msg->field('current');
  my $io = $self->{_io};
  if ($command eq "high") {
    $io->write(sprintf("XA%d", $num));
    $self->state_changed('o', $num, 'high', time);
  } elsif ($command eq "low") {
    $io->write(sprintf("XB%d", $num));
    $self->state_changed('o', $num, 'low', time);
  } elsif ($command eq "pulse") {
    $io->write(sprintf("XA%d", $num));
    sleep(0.15); # TOFIX
    $io->write(sprintf("XB%d", $num));
    $self->state_changed('o', $num, 'low', time);
  } elsif ($command eq "toggle") {
    my $state = $self->current_state('o', $num);
    if ($state eq 'high') {
      $io->write(sprintf("XB%d", $num));
      $self->state_changed('o', $num, 'low', time);
    } else {
      $io->write(sprintf("XA%d", $num));
      $self->state_changed('o', $num, 'high', time);
    }
  } else {
    warn "Unsupported setting: $command\n";
  }
  return 1;
}

=head2 C<process_line()>

This is the callback that processes lines of output from the VIOM.  It
is responsible for sending out the sensor.basic xpl-trig messages.

=cut

sub process_line {
  my ($self, $msg) = @_[0,2];
  my $line = $msg->raw;
  return unless ($line ne '');
  my $time = time;
  if ($line =~ /[01]{16}/) {
    foreach my $index (0..15) {
      my $change = $self->state_changed('i', $index+1,
                                        substr($line, $index, 1),
                                        $time) or next;
      my ($device, $level) = @$change;
      $self->xpl->send_sensor_basic($device, 'input', $level);
    }
  } elsif ($line =~ /^(Input|Output) (\d+) (Inactive|Active)$/) {
    return unless ($self->state_changed(lc $1, $2, $3, $time) ||
                   $self->verbose >= 2);
  }
  $self->info($line, "\n");
  return 1;
}

=head2 C<current_state( $type, $num )>

Returns the current state of the input or output.

=cut

sub current_state {
  my ($self, $type, $num) = @_;
  my $id = (substr $type, 0, 1).(sprintf "%02d", $num);
  return $self->{_state}->{$id}->[0];
}

=head2 C<state_changed( $type, $num, $state, $time )>

This method updates the state table.  If the state has changes, then
it returns an array reference with the id and new state.  If the state
is unchanged, then it returns undef.

=cut

sub state_changed {
  my ($self, $type, $num, $state, $time) = @_;
  my $internal_state = $state_map{$state};
  my $id = (substr $type, 0, 1).(sprintf "%02d", $num);
  my ($old) = @{$self->{_state}->{$id}||['low', $time-1]};
  if ($internal_state ne $old) {
    $self->{_state}->{$id} = [ $internal_state, $time ];
    return [$id, $internal_state];
  } else {
    return;
  }
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

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
