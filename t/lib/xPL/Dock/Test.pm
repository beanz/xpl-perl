package xPL::Dock::Test;
use base xPL::Dock::Plug;
__PACKAGE__->make_readonly_accessor($_) foreach (qw/scalar array
                                                    scalar_not_argv
                                                    array_not_argv/);
sub getopts {
  my $self = shift;
  $self->{_scalar} = undef;
  $self->{_array} = [];
  $self->{_scalar_not_argv} = undef;
  $self->{_array_not_argv} = [];
  return (
          's=s' => \$self->{_scalar},
          'a=s' => $self->{_array},
          'sna=s' => \$self->{_scalar_not_argv},
          'ana=s' => $self->{_array_not_argv},
         );
}
sub init {
  my ($self, $xpl) = @_;
  $self->required_field($xpl, 'scalar',
                        'The -s parameter is required', 1);
  $self->required_field($xpl, 'array',
                        'The -a parameter is required', 1);
  $self->required_field($xpl, 'scalar_not_argv',
                        'The -sna parameter is required', 0);
  $self->required_field($xpl, 'array_not_argv',
                        'The -ana parameter is required', 0);
  return $self->SUPER::init($xpl, @_);
}
sub vendor_id {
  'acme';
}
sub version {
  '0.01';
}

1;
