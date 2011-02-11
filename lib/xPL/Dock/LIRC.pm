package xPL::Dock::LIRC;

=head1 NAME

xPL::Dock::LIRC - xPL::Dock plugin for an LIRC client

=head1 SYNOPSIS

  use xPL::Dock qw/LIRC/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds an LIRC client.

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

__PACKAGE__->make_readonly_accessor($_) foreach (qw/server/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_server} = '/dev/lircd';
  return
    (
     'lirc-verbose+' => \$self->{_verbose},
     'lirc-server=s' => \$self->{_server},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);
  $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_server},
                        port => 8765,
                        input_record_type => 'xPL::IORecord::LFLine',
                        reader_callback => sub { $self->lirc_reader(@_) });
  return $self;
}

=head2 C<lirc_reader( )>

This callback reads data from the LIRC server.

=cut

sub lirc_reader {
  my ($self, $msg) = @_[0,2];
  $self->info($msg,"\n");
  if ($msg->raw =~ m!^\S+ \S{2} (\S+) (\S+)!) {
    my $device = lc($2);
    my $key = lc($1);
    my %args =
      (
       message_type => 'xpl-trig',
       schema => 'remote.basic',
       body => [ device => $device, 'keys' => $key ],
      );
    $self->info("Sending $device $key\n");
    return $self->xpl->send(%args);
  }
  return 0;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), lircd(8)

Project website: http://www.xpl-perl.org.uk/

LIRC website: http://www.lirc.org/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
