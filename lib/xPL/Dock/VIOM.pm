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

sub getopts {
  my $self = shift;
  $self->{_baud} = 9600;
  return (
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

  $self->{_state} = {};

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'viom', callback => \&xpl_in,
                         arguments => $self,
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    class => 'control',
                                    class_type => 'basic',
                                    type => 'output',
                                   });

  # sanity check the inputs immediately and periodically so we keep
  # the current state sane even when viom is unplugged, etc.
  $xpl->add_timer(id => 'input-check', timeout => -631,
                  callback => sub { $self->write('CIN'); 1; });

  # sanity check the outputs immediately and periodically so we keep
  # the current state sane even when viom is unplugged, etc.
  $xpl->add_timer(id => "temp", timeout => 2, count => 1,
                  callback => sub {
                    $self->write('CIC1', 1);
                    $xpl->add_timer(id => 'output-check', timeout => -641,
                                    callback =>
                                      sub { $self->write('COR'); 1; });
                    return;
                  });

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
  my $id = sprintf("o%02d", $num);
  my $command = lc $msg->current;
  if ($command eq "high") {
    $self->write(sprintf("XA%d", $num));
    $state->{$id} = 'high:'.time;
  } elsif ($command eq "low") {
    $self->write(sprintf("XB%d", $num));
    $state->{$id} = 'low:'.time;
  } elsif ($command eq "pulse") {
    $self->write(sprintf("XA%d", $num));
    select(undef,undef,undef,0.15);
    $self->write(sprintf("XB%d", $num));
    $state->{$id} = 'low:'.time;
  } elsif ($command eq "toggle") {
    my ($old,$prev_time) = split(/:/,$state->{$id}||"");
    # assume low
    if ($old eq "high") {
      $self->write(sprintf("XB%d", $num));
      $state->{$id} = 'low:'.time;
    } else {
      $self->write(sprintf("XA%d", $num));
      $state->{$id} = 'high:'.time;
    }
  }
  return 1;
}

=head2 C<process_line()>

This is the callback that processes lines of output from the VIOM.  It
is responsible for sending out the sensor.basic xpl-trig messages.

=cut

sub process_line {
  my ($self, $line) = shift;
  return unless (defined $line && $line ne '');
  my $xpl = $self->xpl;
  my $state = $self->{_state};
  my $time = time;
  if ($line =~ /[01]{16}/) {
    foreach my $index (0..15) {
      my $id = sprintf("i%02d",$index+1);
      my $new = substr($line, $index, 1) ? "high" : "low";
      my ($old,$prev_time) = split(/:/,$state->{$id}||"low:");
      if ($new ne $old) {
        $state->{$id} = $new.":".$time;
        $self->send_xpl($id, $new);
      }
    }
  } elsif ($line =~ /^Input (\d+) (Inactive|Active)$/) {
    my $id = sprintf("i%02d",$1);
    my $new = $2 eq "Active" ? "high" : "low";
    my ($old,$prev_time) = split(/:/,$state->{$id}||"low:");
    if ($new ne $old) {
      $state->{$id} = $new.":".$time;
    } else {
      # only print these if something has changed
      return;
    }
  } elsif ($line =~ /^Output (\d+) (Inactive|Active)$/) {
    my $id = sprintf("o%02d",$1);
    my $new = $2 eq "Active" ? "high" : "low";
    my ($old,$prev_time) = split(/:/,$state->{$id}||"low:");
    if ($new ne $old) {
      $state->{$id} = $new.":".$time;
    } else {
      # only print these if something has changed
      return;
    }
  }
  print $line,"\n" if ($xpl->verbose);
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
  print STDERR "Sending $device $level\n" if ($xpl->verbose);
  return $xpl->send(%args);
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
