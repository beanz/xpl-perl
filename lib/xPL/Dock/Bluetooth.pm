package xPL::Dock::Bluetooth;

=head1 NAME

xPL::Dock::Bluetooth - xPL::Dock plugin for bluetooth proximity reporting

=head1 SYNOPSIS

  use xPL::Dock qw/Bluetooth/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds bluetooth proximity reporting.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use Net::Bluetooth;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval addresses/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_interval} = 60;
  $self->{_addresses} = [];
  return
    (
     'bluetooth-verbose+' => \$self->{_verbose},
     'bluetooth-poll-interval=i' => \$self->{_interval},
     'bluetooth-address=s' => $self->{_addresses},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl, 'addresses',
             'At least one --bluetooth-address parameter is required',
             1);
  $self->SUPER::init($xpl, @_);

  $self->{_watch} = [ map { uc } @{$self->{_addresses}} ];

  $xpl->add_timer(id => 'poll-bluetooth',
                  timeout => -$self->{_interval},
                  callback => sub { $self->poll_bluetooth(@_) });
  return $self;
}

=head2 C<poll_bluetooth()>

This is the timer callback that polls the bluetooth network looking
for visible devices.

=cut

sub poll_bluetooth {
  my $self = shift;
  my $xpl = $self->xpl;
  foreach my $addr (@{$self->{_watch}}) {
    my @sdp_array = sdp_search($addr, '0', '');
    my $state = $sdp_array[0] ? 'high' : 'low';
    $self->xpl->send_sensor_basic('bt.'.$addr, 'input', $state);
  }
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), Net::Bluetooth(3)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
