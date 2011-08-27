package Jet::Node;

use 5.010;
use Moose;

use Jet::Context;

with 'Jet::Role::Log';

=head1 NAME

Jet::Node - Represents Jet Nodes

=head1 SYNOPSIS

=head1 ATTRIBUTES

=cut

has row => (
	isa => 'Jet::Engine::Row',
	is => 'ro',
	writer => '_row',
);
has endpath => (
	isa => 'Str',
	is => 'ro',
);
has basetype => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return $self->row->get_column('base_type');
	},
);
has uri => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return join '/', @{ $self->row->get_column('node_path') };
	},
);

=head1 METHODS

=head2 add

Add a new node

=cut

sub add {
	my ($self, $args) = @_;
	return unless ref $args eq 'HASH';
	for my $column (qw/title part/) {
		return unless defined $args->{$column};
	}

	my $c = Jet::Context->instance();
	my $schema = $c->schema;
	my $opts = {returning => '*'};
	my $row = $schema->insert($self->basetype, $args, $opts);
	$self->_row($schema->row($row, $self->basetype));
}

=head2 move

Move node to a new parent

=cut

sub move {
	my ($self, $parent_id) = @_;
	return unless $parent_id and $self->row;

	my $c = Jet::Context->instance();
	my $schema = $c->schema;
	my $opts = {returning => '*'};
	my $success = $schema->move($self->path_id, $parent_id);
}

=head2 add_child

Add a new child node to the current node

=cut

sub add_child {
	my ($self, $args) = @_;
	return unless ref $args eq 'HASH';

	for my $column (qw/basetype title/) {
		return unless ($args->{$column});
	}
	$args->{parent_id} = $self->row->get_column('path_id');
# XXX TODO Check that basetype is valid
	my $c = Jet::Context->instance();
	my $schema = $c->schema;
	my $basetype = delete $args->{basetype};
	my $opts = {returning => '*'};
	my $child = $schema->insert($basetype, $args, $opts);
	return $self->new(
		row => $schema->row($child, $basetype),
	);
}

=head2 move_child

Move child node here

=cut

sub move_child {
	my ($self, $child_id) = @_;
	return unless $child_id and $self->row;

	my $c = Jet::Context->instance();
	my $schema = $c->schema;
	my $opts = {returning => '*'};
	my $success = $schema->move($child_id, $self->row->get_column('path_id'));
}

=head2 children

Return the children of the current node

=cut

sub children {
	my ($self, %opt) = @_;
	my $c = Jet::Context->instance();
	my $schema = $c->schema;
	my $base_type = $self->basetype || return;

	my $parent_id = $self->row->get_column('path_id');
	$opt{parent_id} = $parent_id;
	my $nodes = $schema->search_nodepath($base_type, \%opt);
	my %nodes;
	for my $node (@$nodes) {
		push @{ $nodes{$node->{base_type}} }, $node;
	}
	my @result;
	while (my ($base_type, $nodes) = each %nodes) {
		for my $node (@{ $nodes }) {
			my $where = {
				parent_id => $parent_id,
				id => $node->{node_id},
			};
			push @result, map {{%$node, %$_}} @{ $schema->search($base_type, $where) };
		}
	}
	return [ map {Jet::Node->new(row => Jet::Engine::Row->new(row_data => $_))} @result ];

# XXX
# Split in relations (base_type)
# For hver relation, find id'er
# For hver relation
# SELECT * FROM data.$relation
# WHERE id IN @ids

# stitch et resultobjekt sammen
}

=head2 parents

Return the parents of the current node

Required parameters:

base_type

=cut

sub parents {
	my ($self, %opt) = @_;
	my $c = Jet::Context->instance();
	my $schema = $c->schema;
	my $parent_base_type = $opt{base_type} || return;

	my $node_id = $self->row->get_column('id');
	my $where = {
		base_type => $self->basetype,
		node_id => $node_id,
	};
	my $nodes = $schema->search_nodepath($self->basetype, \%opt);
	my %nodes;
	for my $node (@$nodes) {
		push @{ $nodes{$node->{base_type}} }, $node;
	}
	my @result;
	while (my ($base_type, $nodes) = each %nodes) {
		for my $node (@{ $nodes }) {
			$where = {
				id => $node->{node_id},
			};
			push @result, map {{%$node, %$_}} @{ $schema->search($base_type, $where) };
		}
	}
	return [ map {Jet::Node->new(row => Jet::Engine::Row->new(row_data => $_))} @result ];
}

# XXX trait
sub file_location {
	my $self = shift;
	my $c = Jet::Context->instance();
	my $basedir = $c->config->{config}{paths}{image}{url};
	my $target_id = $self->row->get_column('id');
	my $td = substr($target_id,-4);
	$td .= '_' x ( 4 - length( $td ) );
	my $targetdir = substr($td,-2).'/'.substr($td,-4,2);
	return join '/', '', $basedir, $targetdir, $target_id, $self->row->get_column('filename');
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 AUTHOR

Kaare Rasmussen, <kaare at cpan dot com>

=head1 BUGS 

Please report any bugs or feature requests to my email address listed above.

=head1 COPYRIGHT & LICENSE 

Copyright 2011 Kaare Rasmussen, all rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as 
Perl itself, either Perl version 5.8.8 or, at your option, any later version of Perl 5 you may 
have available.
