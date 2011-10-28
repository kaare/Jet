package Jet::Engine::Node::MoveTo;

use 5.010;
use Moose;
use File::Copy;
use File::Path;

extends 'Jet::Engine';

with 'Jet::Role::Log';

=head1 NAME

Jet::Engine::Node::MoveTo - Move a node to a new parent


=head1 SYNOPSIS

=head1 METHODS

=head2 data

Moves a node to a new parent

=head1 PARAMETERS

=head2 child_id

Where to find the child

=head2 parent_id

Where to find the parent. Default the current parent

=cut

sub data {
	my $self = shift;
	my $parms = $self->parameters;
	my $child_id = $parms->{child_id};
	my $c = Jet::Context->instance();
	$c->node->move_child($child_id)
}

no Moose::Role;

1;

=head1 AUTHOR

Kaare Rasmussen, <kaare at cpan dot com>

=head1 BUGS 

Please report any bugs or feature requests to my email address listed above.

=head1 COPYRIGHT & LICENSE 

Copyright 2011 Kaare Rasmussen, all rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as 
Perl itself, either Perl version 5.8.8 or, at your option, any later version of Perl 5 you may 
have available.