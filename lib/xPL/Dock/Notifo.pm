package xPL::Dock::Notifo;

=head1 NAME

xPL::Dock::Notifo - xPL::Dock plugin for simple Notifo client

=head1 SYNOPSIS

  use xPL::Dock qw/Notifo/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds a Notifo C<sendmsg.basic> client.  It
sends Notifo notifications when the C<to> field in C<sendmsg.basic>
messages is "C<notifo>".

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use AnyEvent::WebService::Notifo;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  return
    (
     'notifo-verbose+' => \$self->{_verbose},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  $self->{_notifo} = AnyEvent::WebService::Notifo->new;

  $xpl->add_xpl_callback(id => 'xpl_handler',
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'sendmsg.basic',
                          to => 'notifo',
                         },
                         callback => sub { $self->xpl_handler(@_) });
  return $self;
}

=head2 C<xpl_handler( %params )>

This method handles and responds to incoming C<remote.basic> messages.

=cut

sub xpl_handler {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};

  my $text = $msg->field('body') or return;

  $self->info("Sending notifo: $text\n");
  $self->{_notifo}->send_notification(msg => $text,
                                      cb => sub { $self->_resp(@_) });
  return 1;
}

sub _resp {
  my ($self, $res) = @_;
  # $res is our response
  my @body;
  if ($res->{http_response_code} eq '200') {
    @body = ( status => 'success');
  } else {
    @body =
      (
       status => 'attempted',
       error => $res->{http_status_line},
      );
  }
  $self->xpl->send(message_type => 'xpl-trig',
                   schema => 'sendmsg.confirm',
                   body => @body);
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), AnyEvent::WebService::Notifo(3), Protocol::Notifo(3)

Project website: http://www.xpl-perl.org.uk/

Notifo website: http://notifo.com/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2011 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
