package Jet::Engine::Config;

use 5.010;
use Moose;

extends 'Jet::Engine';
with qw/Jet::Role::Log/;

=head1 NAME

Jet::Engine - Configure Jet

=head1 DESCRIPTION

Jet::Engine::Config configures Jet data and nodes.

=head1 ATTRIBUTES

=head2 parts

This is the engine parts

=cut

has _parts => (
	traits	=> [qw/Jet::Trait::Engine/],
	is		=> 'ro',
	isa		=> 'ArrayRef',
	parts => [
#		{'Jet::Part::Basenode' => 'jet_basenode'},
#		{
#			module => 'Jet::Part::Children',
#			alias  => 'jet_children',
#			type => 'json',
#		},
	],
);

=head1 METHODS

=head2 data

Control what to send when it's JSON

=cut

before data => sub {
	my $self = shift;
	$self->stash->{fields} = $self->basenode->datacolumns->fields_as_json;

	# Return json
	my $response = $self->response;
	$response->set_type('json');
	$self->set_renderer;
	$response->renderer->set_expose_stash('fields');
};

__PACKAGE__->meta->make_immutable;

# COPYRIGHT

__END__
