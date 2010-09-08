package xPL::Dock::GPower;

=head1 NAME

xPL::Dock::GPower - xPL::Dock plugin for sending wake-on-lan packets

=head1 SYNOPSIS

  use xPL::Dock qw/GPower/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds a client to submit data using the Google
PowerMeter API.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use HTTP::Request;
use LWP::UserAgent;
use POSIX qw/strftime/;
eval { require YAML::Syck; import YAML::Syck qw/LoadFile/; };
if ($@) {
  eval { require YAML; import YAML qw/LoadFile/; };
  die "Failed to load YAML::Syck or YAML module: $@\n" if ($@);
}

use xPL::Dock::Plug;

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
  $self->{_config_file} = '/etc/xplperl/gpower.conf';
  return
    (
     'gpower-verbose+' => \$self->{_verbose},
     'gpower-config=s' => \$self->{_config_file},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $self->{_cfg} = LoadFile($self->{_config_file});
  $self->{_ua} = LWP::UserAgent->new();
  $self->argh('Must defined user_id in configuration file')
    unless (defined $self->{_cfg}->{user_id});
  $self->argh('Must defined auth_token in configuration file')
    unless (defined $self->{_cfg}->{auth_token});
  $self->argh('Must defined device in configuration file')
    unless (defined $self->{_cfg}->{device});

  $xpl->add_xpl_callback(id => 'xpl_handler',
                         filter =>
                         {
                          class => 'sensor.basic',
                         },
                         callback => sub { $self->xpl_handler(@_) });

  # init batch struct
  $self->{_entries} = {
                       text => '',
                       batch_id => 0,
                       next_time => time, # send immediately first time
                      };

  return $self;
}

=head2 C<xpl_handler( %params )>

This method handles and responds to incoming C<remote.basic> messages.

=cut

sub xpl_handler {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};

  unless (defined $msg->field('type') && (lc $msg->field('type')) eq 'current') {
    return;
  }

  my $rec = $self->{_cfg}->{variables}->{lc $msg->field('device')};
  unless (defined $rec) {
    return;
  }
  my $end_time = time;
  my $start_time;
  if (exists $self->{_last}->{$rec}) {
    $start_time = $self->{_last}->{$rec};
  } else {
    $self->ensure_variable_exists($rec);
    $start_time = $end_time - 6;
  }
  $self->{_last}->{$rec} = $end_time;
  my $watts = $msg->field('current') * 240;
  my $duration = $end_time - $start_time;
  my $kwh = ($watts / ( 3600 / $duration ) ) / 1000;
  $self->info($msg->field('device'), ": ", $kwh, "kwh\n");
  $self->queue_batch_entry($rec, $start_time, $end_time, $kwh);
  return 1;
}

sub submit {
  my ($self, $rec, $start, $end, $kwh) = @_;
  my $auth_token = $self->{_cfg}->{auth_token};
  my $user_id = $self->{_cfg}->{user_id};
  my $variable_id = $self->{_cfg}->{device}.'.'.$rec->{id};
  my $entry = q{<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
       xmlns:meter="http://schemas.google.com/meter/2008">
  <meter:startTime meter:uncertainty="1.0">}.ts($start).q{</meter:startTime>
  <meter:endTime meter:uncertainty="1.0">}.ts($end).q{</meter:endTime>
  <meter:quantity meter:uncertainty="0.001"
                  meter:unit="kW h">}.$kwh.q{</meter:quantity></entry>};
  my $url =
    'https://www.google.com/powermeter/feeds/user/'.
      $user_id.'/'.$user_id.'/variable/'.$variable_id.'/durMeasurement';
  my $req = HTTP::Request->new(POST => $url);
  $req->header('Authorization' => 'AuthSub token="'.$auth_token.'"');
  $req->content_type('application/atom+xml');
  $req->content($entry);
  my $response = $self->{_ua}->request($req);
  unless ($response->is_success) {
    $self->argh("Update for ", $rec->{id}, " failed:\n",
                $response->status_line(), "\n",
                $response->content);
  }
}

sub ts {
  strftime '%Y-%m-%dT%H:%M:%S.000Z', gmtime $_[0]
}

sub queue_batch_entry {
  my ($self, $rec, $start, $end, $kwh) = @_;
  my $auth_token = $self->{_cfg}->{auth_token};
  my $user_id = $self->{_cfg}->{user_id};
  my $variable_id = $self->{_cfg}->{device}.'.'.$rec->{id};
  my $entry = q{
<entry>
  <category scheme="http://schemas.google.com/g/2005#kind"
            term="http://schemas.google.com/meter/2008#durMeasurement"/>
  <meter:subject>
    https://www.google.com/powermeter/feeds/user/}.$user_id.'/'.$user_id.'/variable/'.$variable_id.q{
  </meter:subject>
  <batch:id>}.$self->{_entries}->{batch_id}++.q{</batch:id>
  <meter:startTime meter:uncertainty="1.0">}.ts($start).q{</meter:startTime>
  <meter:endTime meter:uncertainty="1.0">}.ts($end).q{</meter:endTime>
  <meter:quantity meter:uncertainty="0.001"
                  meter:unit="kW h">}.$kwh.q{</meter:quantity>
</entry>};

  $self->{_entries}->{text} .= $entry;
  if (time > $self->{_entries}->{next_time}) {
    $self->send_batch();
  }
}

sub send_batch {
  my ($self) = @_;
  my $batch = $self->{_entries}->{text} || return;
  my $count = $self->{_entries}->{batch_id};
  $self->{_entries} = {
                       text => '',
                       batch_id => 0,
                       next_time => time + 630, # 10m plus a bit
                      };

  my $url = 'https://www.google.com/powermeter/feeds/event';
  my $req = HTTP::Request->new(POST => $url);
  $req->header('Authorization' =>
                 'AuthSub token="'.$self->{_cfg}->{auth_token}.'"');
  $req->content_type('application/atom+xml');
  my $content = q{  <?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:meter="http://schemas.google.com/meter/2008"
      xmlns:batch="http://schemas.google.com/gdata/batch">
}.$batch.q{
</feed>
};

  $req->content($content);
  my $response = $self->{_ua}->request($req);
  if ($response->is_success) {
    $self->info('Sent batch of '.$count." entries\n");
  } else {
    $self->argh("Batch update failed:\n", $response->status_line(), "\n",
                $response->content);
  }
}

sub ensure_variable_exists {
  my ($self, $rec) = @_;
  my $auth_token = $self->{_cfg}->{auth_token};
  my $user_id = $self->{_cfg}->{user_id};
  my $variable_id = $self->{_cfg}->{device}.'.'.$rec->{id};
  my $title = $rec->{title} || 'Electricity Consumption';
  my $desc = $rec->{desc} || 'Electricity Consumption';
  my $location = $rec->{location} || 'Unknown';

  my $entry = q{<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
       xmlns:meter="http://schemas.google.com/meter/2008">
  <meter:variableId>}.$variable_id.q{</meter:variableId>
  <title>}.$title.q{</title>
  <content type="text">}.$desc.q{</content>
  <meter:location>}.$location.q{</meter:location>
  <meter:type>electricity_consumption</meter:type>
  <meter:unit>kW h</meter:unit>
  <meter:durational/>
</entry>};
  print $entry, "\n";
  my $url =
    'https://www.google.com/powermeter/feeds/user/'.
      $user_id.'/'.$user_id.'/variable';
  my $req = HTTP::Request->new(POST => $url);
  $req->header('Authorization' => 'AuthSub token="'.$auth_token.'"');
  $req->content_type('application/atom+xml');
  $req->content($entry);
  my $response = $self->{_ua}->request($req);
  unless ($response->is_success) {
    $self->argh("Init for ", $variable_id, " failed");
  }
  1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3)

Project website: http://www.xpl-perl.org.uk/

Google PowerMeter website: http://www.google.com/powermeter/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
