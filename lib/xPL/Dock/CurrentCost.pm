package xPL::Dock::CurrentCost;

=head1 NAME

xPL::Dock::CurrentCost - xPL::Dock plugin for an CurrentCost Receiver

=head1 SYNOPSIS

  use xPL::Dock qw/CurrentCost/;
  my $xpl = xPL::Dock->new(name => 'ccost');
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
use xPL::IOHandler;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

{
 package xPL::IORecord::CCXML;
 use base 'xPL::IORecord::XML';
 sub tag { qr/msg/ }
 1;
}

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  # use '--currentcost-baud 9600' for original current cost
  $self->{_baud} = 57600;
  return
    (
     'currentcost-verbose+' => \$self->{_verbose},
     'currentcost-baud=i' => \$self->{_baud},
     'currentcost-tty=s' => \$self->{_device},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->required_field($xpl,
                        'device',
                        'The --currentcost-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  my $io = $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        reader_callback => sub { $self->device_reader(@_) },
                        input_record_type => 'xPL::IORecord::CCXML',
                        discard_buffer_timeout => 0.1);
  return $self;
}

=head2 C<device_reader()>

This is the callback that processes output from the CurrentCost.  It is
responsible for sending out the xPL messages.

=cut

sub device_reader {
  my ($self, $handler, $msg, $last) = @_;
  my $xpl = $self->xpl;
  my $xml = $msg->str;
  # discard messages without a start tag - incomplete messages
  return 1 if ($xml =~ /<hist>/); # ignore historical data messages
  $xml =~ m!<msg>(.*?)</msg>!s;
  my $data = $1;
  my $base_type;
  my @dev_keys;
  if ($data =~ s!<src><name>([^<]+)</name>(.*?)</src>!<src>$1</src>$2!g) {
    $base_type = 'curcost';
    @dev_keys = qw/id/;
  } else {
    $base_type = 'cc128';
    @dev_keys = qw/id sensor/;
  }
  # xml hack
  $data =~ s!\s*<([^>]+)>([^<]+)</\1>\s*!$1=$2 !g;
  $data =~ s!\s*<([^>]+)>([^<]+)</\1>\s*! $1.$2!g;
  my %data = map { split /=/, $_, 2 } split /\s+/, $data;
  #print "D: $_ => ", $data{$_}, "\n" foreach (keys %data);
  my $device = join '.', $base_type, map { lc $_ } @data{@dev_keys};

  if ($data{'type'} == 1) { # elec
    $data{'total.watts'} =
      $data{'ch1.watts'}+$data{'ch2.watts'}+$data{'ch3.watts'};
    foreach my $p ('total', 'ch1', 'ch2', 'ch3') {
      my $v = $data{$p.'.watts'}/240;
      my $dev = $device.($p eq 'total' ? '' : '.'.substr $p, 2, 1);
      my $xplmsg =
        xPL::Message->new(message_type => 'xpl-trig',
                          head => { source => $xpl->id, },
                          class => 'sensor.basic',
                          body =>
                          {
                           device => $dev,
                           type => 'current',
                           current => $v,
                          });
      print $xplmsg->summary,"\n";
      $xpl->send($xplmsg);
    }
    my $xplmsg =
      xPL::Message->new(message_type => 'xpl-trig',
                        head => { source => $xpl->id, },
                        class => 'sensor.basic',
                        body =>
                        {
                         device => $device,
                         type => 'temp',
                         current => $data{tmpr},
                        });
    print $xplmsg->summary,"\n";
    $xpl->send($xplmsg);
  } else {
    warn "Sensor type: ", $data{type},
      " not supported.  Message was:\n", $msg,"\n";
  }
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Current Cost website: http://www.currentcost.com/

Current Cost XML Format: http://www.currentcost.com/cc128/xml.htm

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
