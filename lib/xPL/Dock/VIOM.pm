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
use Pod::Usage;
use xPL::Dock::SerialLine;

our @ISA = qw(xPL::Dock::SerialLine);
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

sub getopts {
  my $self = shift;
  $self->{_baud} = 9600;
  $self->{_verbose} = 0;
  return (
          'viom-verbose|viomverbose+' => \$self->{_verbose},
          'viom-baud|viombaud=i' => \$self->{_baud},
          'viom=s' => \$self->{_device},
         );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  defined $self->{_device} or
    pod2usage(-message => "The --viom parameter is required",
              -exitstatus => 1);
  $self->SUPER::init($xpl,
                     reader_callback => \&process_line,
                     output_record_separator => "\r\n",
                     @_);

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
                                    class => 'control',
                                    class_type => 'basic',
                                    type => 'output',
                                   });

  $self->write('CSV', 1); # report software version
  $self->write('CIC1', 1); # turn on input status change reporting

  # sanity check the inputs immediately and periodically so we keep
  # the current state sane even when viom is unplugged, etc.
  $xpl->add_timer(id => 'input-check', timeout => -631,
                  callback => sub { $self->write('CIN'); 1; });

  # sanity check the outputs immediately and periodically so we keep
  # the current state sane even when viom is unplugged, etc.
  $xpl->add_timer(id => 'output-check', timeout => -641,
                  callback =>
                  sub { $self->write('COR'); 1; });

  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming control.basic schema messages.

=cut

sub xpl_in {
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};
  my $self = $p{arguments};
  my $xpl = $self->xpl;
  my $state = $self->{_state};

  return 1 unless ($msg->device =~ /^o(\d+)$/);
  my $num = $LAST_PAREN_MATCH;
  my $command = lc $msg->current;
  if ($command eq "high") {
    $self->write(sprintf("XA%d", $num));
    $self->state_changed('o', $num, 'high', time);
  } elsif ($command eq "low") {
    $self->write(sprintf("XB%d", $num));
    $self->state_changed('o', $num, 'low', time);
  } elsif ($command eq "pulse") {
    $self->write(sprintf("XA%d", $num));
    select(undef,undef,undef,0.15);
    $self->write(sprintf("XB%d", $num));
    $self->state_changed('o', $num, 'low', time);
  } elsif ($command eq "toggle") {
    my $state = $self->current_state('o', $num);
    if ($state eq 'high') {
      $self->write(sprintf("XB%d", $num));
      $self->state_changed('o', $num, 'low', time);
    } else {
      $self->write(sprintf("XA%d", $num));
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
  my ($self, $line) = @_;
  return unless (defined $line && $line ne '');
  my $xpl = $self->xpl;
  my $state = $self->{_state};
  my $time = time;
  if ($line =~ /[01]{16}/) {
    foreach my $index (0..15) {
      my $change = $self->state_changed('i', $index+1,
                                        substr($line, $index, 1),
                                        $time) or next;
      $self->send_xpl(@$change);
    }
  } elsif ($line =~ /^(Input|Output) (\d+) (Inactive|Active)$/) {
    return unless ($self->state_changed(lc $1, $2, $3, $time) ||
                   $self->verbose >= 2);
  }
  print $line,"\n" if ($self->verbose);
  return 1;
}

=head2 C<send_xpl( $device, $level )>

This functions is used to send out sensor.basic xpl-trig messages as a
result of changes to the VIOM inputs.

=cut

sub send_xpl {
  my $self = shift;
  my $device = shift;
  my $level = shift;
  my $xpl = $self->xpl;
  my %args =
    (
     message_type => 'xpl-trig',
     class => 'sensor.basic',
     body => { device => $device, type => 'input', current => $level },
    );
  print "Sending $device $level\n" if ($self->verbose);
  return $xpl->send(%args);
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
  my ($old, $old_time) = @{$self->{_state}->{$id}||['low', $time-1]};
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

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
